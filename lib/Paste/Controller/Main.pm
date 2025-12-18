package Paste::Controller::Main;

use Mojo::Base 'Mojolicious::Controller';
use Digest::SHA qw(sha1_hex);
use Mojo::JSON qw(encode_json);

# Controller emulating the old CGI behaviors with Mojolicious routes
sub index {
    my $c = shift;

    return $c->_create if $c->req->method eq 'POST';

    # Legacy query params support
    for my $spec (
        [ plain     => 'plain',    0 ],
        [ plainh    => 'plain',    1 ],
        [ download  => 'download', 0 ],
        [ downloadh => 'download', 1 ],
        [ hidden    => 'show',     1 ],
        [ show      => 'show',     0 ],
    ) {
        my ( $param, $method, $hidden ) = @$spec;
        if ( defined( my $id = $c->param($param) ) ) {
            $c->stash( id => $id, hidden => $hidden );
            return $c->$method();
        }
    }

    my $pnew      = $c->param('pnew');
    my $as_hidden = $c->param('as_hidden') ? 1 : 0;
    my $status    = $c->flash('status');

    my $prefill_code;
    if ($pnew) {
        $pnew =~ s/[^0-9]+//g;
        my $base = $c->paste_model->get_paste($pnew);
        $prefill_code = $base->{code} if $base;
    }

    my $langs = $c->paste_model->get_langs || [];

    $c->render_tt(
        'paste',
        {   pnew      => $pnew,
            status    => $status,
            as_hidden => $as_hidden,
            langs     => $langs,
            prefill_code => $prefill_code,
        }
    );
}

sub show {
    my $c      = shift;
    my $hidden = $c->stash('hidden') || 0;
    my $id     = $c->stash('id') || '';
    my $lines  = defined $c->param('lines') ? $c->param('lines') : 1;

    $id =~ s/[^0-9a-f]+//g;
    my $tmpl = $hidden ? 'hidden' : 'show';

    my $entry = $c->paste_model->get_paste_display( $id, $hidden );
    return $c->_error( "Entry not found",
        "Your requested paste entry '$id' could not be found" )
        unless $entry;

    my $comments = $c->paste_model->get_comments( $entry->{id} ) || [];
    return $c->_error( "Entry not found",
        "Your requested paste entry '$id' could not be found" )
        if $c->paste_model->error;

    my $own_entry =
        $c->cookie('session_id')
        && $entry->{sessionid}
        && $c->cookie('session_id') eq $entry->{sessionid};
    $entry->{hidden_id} ||= $id if $hidden;

    $c->render_tt(
        $tmpl,
        {   show   => $id,
            lines  => $lines,
            status => $c->flash('status'),
            entry  => $entry,
            comments => $comments,
            own_entry => $own_entry,
        }
    );
}

sub plain {
    my $c      = shift;
    my $hidden = $c->stash('hidden') || 0;
    my $id     = $c->stash('id') || '';

    $id =~ s/[^0-9a-f]+//g;

    my $paste =
          $hidden
        ? $c->paste_model->get_hidden_paste($id)
        : $c->paste_model->get_paste($id);

    return $c->_error( "Entry not found",
        "Your requested paste entry '$id' could not be found" )
        unless $paste;

    $c->res->headers->content_type('text/plain; charset=utf-8');
    $c->render( data => $paste->{code} );
}

sub download {
    my $c      = shift;
    my $hidden = $c->stash('hidden') || 0;
    my $id     = $c->stash('id') || '';

    $id =~ s/[^0-9a-f]+//g;

    my $paste =
          $hidden
        ? $c->paste_model->get_hidden_paste($id)
        : $c->paste_model->get_paste($id);

    return $c->_error( "Entry not found",
        "Your requested paste entry '$id' could not be found" )
        unless $paste;

    $c->res->headers->content_type('text/plain; charset=utf-8');
    $c->res->headers->content_disposition("attachment; filename=paste_$id");
    $c->render( data => $paste->{code} );
}

sub delete {
    my $c      = shift;
    my $digest = $c->stash('digest') || '';

    $digest =~ s/[^0-9a-f]+//g;

    my $id = $c->paste_model->delete_paste($digest);
    return $c->_error( "Entry could not be deleted", $c->paste_model->error )
        if $c->paste_model->error;

    $c->render_tt(
        'show_message',
        {   title   => "Entry $id deleted",
            message => "The entry with the id $id has been deleted.",
        }
    );
}

sub comment {
    my $c = shift;

    my $comment  = $c->param('comment');
    my $paste_id = $c->param('paste_id');
    my $name     = $c->param('poster') || 'anonymous';

    $paste_id =~ s/[^0-9a-f]+//g if defined $paste_id;

    return $c->_error( "Could not add comment", "Please add a comment" )
        unless $comment;
    return $c->_error( "Could not add comment", "No Paste id found" )
        unless $paste_id;

    $c->paste_model->add_comment( $comment, $name, $paste_id );

    return $c->_error( "Comment could not be added", $c->paste_model->error )
        if $c->paste_model->error;

    my $target =
          $c->stash('hidden')
        ? $c->url_for( 'show_hidden', id => $c->stash('id') )
        : $c->url_for( 'show',        id => $paste_id );
    $c->flash( status =>
            "Your comment has been added to paste entry $paste_id." );
    return $c->redirect_to($target);
}

sub page {
    my $c     = shift;
    my $tmpl  = $c->stash('tmpl');
    my @allow = qw(about clients);

    return $c->_error( "Page not found", "Page not found" )
        unless grep { $_ eq $tmpl } @allow;

    $c->render_tt( $tmpl, {} );
}

sub login {
    my $c = shift;
    return $c->redirect_to('/') unless $c->app->defaults('auth_enabled');

    my $cb =
          $c->base_url
        . '/auth/callback';
    my $state = $c->csrf_token;
    $c->session( oauth_state => $state );
    $c->redirect_to(
        $c->oauth2->auth_url(
            gitlab => {
                redirect_uri => $cb,
                scope        => 'read_user',
                state        => $state,
            }
        )
    );
}

sub callback {
    my $c = shift;
    return $c->redirect_to('/') unless $c->app->defaults('auth_enabled');

    my $state = $c->param('state') || '';
    if ( !$c->session('oauth_state') || $state ne $c->session('oauth_state') )
    {
        return $c->_error( "Authentication failed",
            "Invalid OAuth state, please retry." );
    }

    my $cb =
          $c->base_url
        . '/auth/callback';

    my ($res) = $c->oauth2->get_token_p(
        gitlab => {
            redirect_uri => $cb,
        }
    )->wait;

    return $c->_error( "Authentication failed", $res ) unless ref $res;
    return $c->_error( "Authentication failed", "No token received" )
        unless $res->{access_token};

    my $ua    = Mojo::UserAgent->new;
    my $site  = $ENV{GITLAB_API_URL} || $ENV{GITLAB_SITE} . '/api/v4';
    my $fetch_res = $ua->get(
        $site . '/user' => { Authorization => "Bearer $res->{access_token}" } )
        ->result;
    return $c->_error( "Authentication failed",
        $fetch_res->message || "GitLab user fetch failed" )
        if $fetch_res->is_error;

    my $user = $fetch_res->json || {};
    my $user_session = { id => $user->{id}, name => $user->{name} };
    my $session_id   = sha1_hex( $user->{id} );
    $c->session( user => $user_session );
    $c->cookie( session_id => $session_id,
        { expires => time + 60 * 60 * 24 * 30 } );
    $c->session( oauth_state => undef );
    $c->flash( status => "Signed in as $user->{name}" );
    return $c->redirect_to('/');
}

sub logout {
    my $c = shift;
    delete $c->session->{user};
    $c->cookie( session_id => undef, { expires => 1 } );
    $c->flash( status => "Signed out" );
    return $c->redirect_to('/');
}

sub _create {
    my $c = shift;
    my $code;
    my $upload = $c->req->upload('upload');

    if ( $upload && $upload->size ) {
        $code = $upload->slurp;
    } else {
        $code = $c->param('code') // '';
        $code = Encode::decode( 'UTF-8', $code )
            unless Encode::is_utf8($code);
    }

    if ( $ENV{PASTE_DEBUG_PARAMS} ) {
        my $params = $c->req->params->to_hash;
        $c->app->log->debug(
            'paste form params: '
                . encode_json($params)
                . ' content_type='
                . ( $c->req->headers->content_type || '' )
                . ' content_length='
                . ( $c->req->headers->content_length || 0 ) );
        for my $u ( @{ $c->req->uploads // [] } ) {
            next unless $u && ref $u;
            $c->app->log->debug(
                'upload detected: '
                    . ( $u->name // '' ) . '/'
                    . ( $u->filename // '' ) . ' size='
                    . ( $u->size // 0 ) );
        }
    }

    my $langs = $c->paste_model->get_langs || [];
    return $c->render_tt(
        'paste',
        {   langs  => $langs,
            status => 'Please add some text to paste.'
        }
        )
        unless ( defined($code) && length $code )
        || $c->req->upload('upload');

    if ( _looks_binary($code) ) {
        return $c->render_tt(
            'paste',
            {   langs  => $langs,
                status => 'Binary uploads are not allowed (#8).'
            }
        );
    }

    my $name = $c->param('poster') || 'anonymous';

    my $session_id =
           $c->param('session_id')
        || $c->cookie('session_id')
        || sha1_hex( rand() . time() );

    my $wrap   = $c->param('wrap');
    my $expire = defined $c->param('expire') ? $c->param('expire') : 86400;
    my $lang   = defined $c->param('lang')   ? $c->param('lang')   : -1;
    my $hidden = 't';    # enforce hidden pastes by default

    my $cgi_obj = _build_cgi_from_tx($c);

    my $authenticated = $c->current_user ? 1 : 0;
    $session_id = sha1_hex( $c->current_user->{id} )
        if $c->current_user && !$c->cookie('session_id');

    my ( $id, $digest ) = $c->paste_model->add_paste(
        {   code       => $code,
            name       => $name,
            expire     => $expire,
            lang       => $lang,
            session_id => $session_id,
            hidden     => $hidden,
            wrap       => $wrap,
            cgi        => $cgi_obj,
            authenticated => $authenticated,
        }
    );

    if ( $c->paste_model->error ) {
        my $status = "Could not add your entry to the paste database:<br><br>\n";
        $status .= '<b>' . $c->paste_model->error . '</b><br>';
        return $c->render_tt( 'paste', { status => $status, langs => $langs } );
    }

    if ( my $remember = $c->param('remember') ) {
        my $expires = time + 60 * 60 * 24 * 60;    # ~2 months
        if ( $remember eq 'both' ) {
            $c->cookie( paste_lang   => $c->param('lang'),   { expires => $expires } );
            $c->cookie( paste_expire => $c->param('expire'), { expires => $expires } );
        }
        $c->cookie( paste_name => $name, { expires => $expires } );
        $c->cookie( session_id => $session_id,
            { expires => time + 60 * 60 * 24 * 30 } );
    } else {
        $c->cookie( session_id => $session_id,
            { expires => time + 60 * 60 * 24 * 30 } );
    }

    my $location = $hidden eq 'f' ? "/$id" : "/hidden/$id";
    return $c->redirect_to($location);
}

sub _error {
    my ( $c, $title, $errormessage ) = @_;
    $c->render_tt(
        'show_message',
        { title => $title, message => $errormessage }
    );
}

sub _build_cgi_from_tx {
    my ($c) = @_;
    my $addr = $c->req->headers->header('X-Forwarded-For')
        || $c->tx->remote_address
        || $c->req->url->to_abs->host;
    return bless { remote_host => $addr }, 'Paste::CGIShim';
}

sub _looks_binary {
    my ($text) = @_;
    return 1 if !defined $text || $text eq '';
    return 1 if $text =~ /\0/;
    use bytes;
    my $len = length($text);
    return 0 if $len == 0;
    my $non_printable = ( $text =~ tr/\x00-\x08\x0B\x0C\x0E-\x1F\x80-\xFF// );
    return ( $non_printable / $len ) > 0.3;
}

package Paste::CGIShim;

sub remote_host {
    my $self = shift;
    return $self->{remote_host};
}

1;

# vim: syntax=perl sw=4 ts=4 noet shiftround
