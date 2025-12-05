package Paste::App;

use Mojo::Base 'Mojolicious';
use POSIX qw(floor);
use Template;
use Paste;
use Mojo::JSON qw(encode_json);

sub startup {
    my $self = shift;

    # Load config and core objects once; keep TT templates unchanged
    my $config_file =
        $ENV{PASTE_CONFIG}
        || $self->home->child('paste.conf')->to_string;

    my $paste    = Paste->new($config_file);
    my $tt = Template->new(
        {   INCLUDE_PATH => $self->home->child('templates')->to_string,
            PLUGIN_BASE  => 'Paste::Template::Plugin',
        }
    );

    my $dbname =
           $ENV{DB_NAME}
        || $paste->get_config_key( 'database', 'dbname' )
        || die "Databasename not specified";
    my $dbuser =
           $ENV{DB_USER}
        || $paste->get_config_key( 'database', 'dbuser' )
        || die "Databaseuser not specified";
    my $dbpass =
          defined $ENV{DB_PASSWORD}
        ? $ENV{DB_PASSWORD}
        : ( $paste->get_config_key( 'database', 'dbpassword' ) || '' );
    my $base_url   = $ENV{BASE_URL} || $paste->get_config_key( 'www', 'base_url' ) || '';

    $self->defaults(
        dbname     => "dbi:Pg:dbname=$dbname",
        dbuser     => $dbuser,
        dbpass     => $dbpass,
        base_url   => $base_url,
    );

    $self->helper( paste_model   => sub { return $paste } );
    $self->helper( tt             => sub { return $tt } );
    $self->helper(
        render_tt => sub {
            my ( $c, $template, $vars ) = @_;
            my $output = '';
            local %ENV = %{ $c->req->env };    # TT CGI plugin expects %ENV
            $c->paste_model->cleanup_expired;
            my $user_pastes = [];
            if ( my $sid = $c->cookie('session_id') ) {
                $user_pastes = $c->paste_model->get_user_pastes($sid) || [];
            }
            my %stash =
                (   %{ $c->stash },
                    %{ $vars || {} },
                    round        => sub { floor(@_) },
                    user_pastes  => $user_pastes,
                    current_user => $c->current_user,
                    auth_enabled => $c->app->defaults('auth_enabled'),
                );
            $c->app->tt->process( $template, \%stash, \$output )
                or die $c->app->tt->error . "\n";
            $c->render(
                data    => $output,
                format  => 'html',
                charset => 'utf-8'
            );
        }
    );

    push @{ $self->static->paths }, $self->home->to_string;

    my $r = $self->routes;
    $r->namespaces( ['Paste::Controller'] );

    if (   $ENV{GITLAB_SITE}
        && $ENV{GITLAB_CLIENT_ID}
        && $ENV{GITLAB_CLIENT_SECRET} )
    {
        $self->plugin(
            'OAuth2',
            providers => {
                gitlab => {
                    key           => $ENV{GITLAB_CLIENT_ID},
                    secret        => $ENV{GITLAB_CLIENT_SECRET},
                    site          => $ENV{GITLAB_SITE},
                    authorize_url => $ENV{GITLAB_AUTHORIZE_URL}
                        || "$ENV{GITLAB_SITE}/oauth/authorize",
                    token_url => $ENV{GITLAB_TOKEN_URL}
                        || "$ENV{GITLAB_SITE}/oauth/token",
                }
            }
        );
        $self->defaults( auth_enabled => 1 );
    } else {
        $self->defaults( auth_enabled => 0 );
    }

    $self->helper( current_user => sub { shift->session('user') } );

    $r->get('/')->to('main#index');
    $r->post('/')->to('main#index');

    $r->get('/plain/:id')->to( 'main#plain', hidden => 0, id => qr/[0-9]+/ )
        ->name('plain');
    $r->get('/plainh/:id')
        ->to( 'main#plain', hidden => 1, id => qr/[0-9a-f]+/ )
        ->name('plain_hidden');

    $r->get('/download/:id')
        ->to( 'main#download', hidden => 0, id => qr/[0-9]+/ )
        ->name('download');
    $r->get('/downloadh/:id')
        ->to( 'main#download', hidden => 1, id => qr/[0-9a-f]+/ )
        ->name('download_hidden');

    $r->get('/hidden/:id')
        ->to( 'main#show', hidden => 1, id => qr/[0-9a-f]+/ )
        ->name('show_hidden');
    $r->get('/hidden/:id/')
        ->to( 'main#show', hidden => 1, id => qr/[0-9a-f]+/ );
    $r->get('/delete/:digest')->to('main#delete')->name('delete_entry');

    $r->post('/comment')->to('main#comment')->name('comment');
    $r->post('/hidden/:id')
        ->to( 'main#comment', hidden => 1, id => qr/[0-9a-f]+/ );
    $r->post('/:id')->to( 'main#comment', hidden => 0 );
    $r->get('/page/:tmpl')->to('main#page')->name('page');

    $r->get('/auth/login')->to('main#login')->name('login');
    $r->get('/auth/callback')->to('main#callback')->name('login_callback');
    $r->get('/logout')->to('main#logout')->name('logout');

    $r->get('/:id')->to( 'main#show', hidden => 0, lines => 1 )
        ->name('show');
    $r->get('/:id/')->to( 'main#show', hidden => 0, lines => 1 );
}

1;

# vim: syntax=perl sw=4 ts=4 noet shiftround
