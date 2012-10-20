package MT::Plugin::OMV::MailSync;
# $Id$

use strict;
use MT::Entry;
use MT::Mail;

use vars qw( $VENDOR $MYNAME $VERSION );
($VENDOR, $MYNAME) = (split /::/, __PACKAGE__)[-2, -1];
(my $revision = '$Rev$') =~ s/\D//g;
$VERSION = '0.10'. ($revision ? ".$revision" : '');

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new({
    name => $MYNAME,
    id => lc $MYNAME,
    key => lc $MYNAME,
    version => $VERSION,
    author_name => 'Open MagicVox.net',
    author_link => 'http://www.magicvox.net/',
    doc_link => 'http://www.magicvox.net/archive/2010/04291519/',
    description => <<PERLHEREDOC,
<__trans phrase="Synchronize the posted entry onto the external blogs with MT::Mail">
PERLHEREDOC
#    l10n_class => $MYNAME. '::L10N',
    blog_config_template => 'config.tmpl',
    settings => new MT::PluginSettings([
        [ 'settings', { Default => undef, scope => 'blog' } ],
    ]),
});
MT->add_plugin ($plugin);

sub instance { $plugin; }



MT->add_callback ('BuildFile', 5, $plugin, \&_entry_post_save);
sub _entry_post_save {
    my ($eh, %opt) = @_;

    my $ctx = $opt{Context};
    my $blog = $ctx->stash ('blog')
        or return 1;
    my $entry = $ctx->stash ('entry')
        or return 1;

    my $settings = &instance->get_config_value ('settings', 'blog:'. $blog->id)
        or return 1; # no settings

    my $tmpl = MT::Template->load ({ blog_id => $blog->id, name => $MYNAME })
        or return 1;
    my $ctx = $tmpl->context;
    $ctx->stash ('blog', $blog);
    $ctx->stash ('entry', $entry);
    my ($title, $body) = $tmpl->output =~ m/(.+)\s+([\s\S]+)/;

    my $pdata = load_plugindata (key_name ($entry->id)) || {};
    foreach (split /[\r\n]+/, $settings) {
        if (!$pdata->{$_} && $entry->status == MT::Entry::RELEASE()) {
            my ($to_addr, $from_addr) = split /,/;
            my %head = (
                To => $to_addr,
                $from_addr ? ('Return-Path' => "$MYNAME <$from_addr>") : (),
                $from_addr ? (From => "$MYNAME <$from_addr>") : (),
                Subject => $title,
            );
            $pdata->{$_} = MT::Mail->send (\%head, $body)
                or die MT::Mail->errstr;

        }
    }
    save_plugindata (key_name ($entry->id), $pdata);
    1;
}



########################################################################
sub key_name { 'entry_id:'. $_[0]; }

use MT::PluginData;

sub save_plugindata {
    my ($key, $data_ref) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key => $key });
    if (!$pd) {
        $pd = MT::PluginData->new;
        $pd->plugin( &instance->id );
        $pd->key( $key );
    }
    $pd->data( $data_ref );
    $pd->save;
}

sub load_plugindata {
    my ($key) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key => $key })
        or return undef;
    $pd->data;
}

1;
__END__
