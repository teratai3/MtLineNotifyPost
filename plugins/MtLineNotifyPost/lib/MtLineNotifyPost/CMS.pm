package MtLineNotifyPost::CMS;
use strict;
use warnings;

use MT::Entry;
use MT::I18N;
use MT::Log;
use utf8;
use LWP::UserAgent;
use MT::PluginData;
use MT::Util qw( trim );

sub post_entry {
    my ( $cb, $app, $obj, $original ) = @_;

    # require MT::Entry;
    # return unless $obj->status == MT::Entry::RELEASE();
    my $blog  = $app->blog;
    my $title = $obj->title;
    my $url   = $obj->permalink;

    my $created_on  = $obj->created_on;
    my $modified_on = $obj->modified_on;

    my $message = "Movable TypeからLINEに通知を送信します。\n";
    $message .= "ブログ名：" . $blog->name . "\n";
    $message .= "タイトル：$title\n";
    $message .= "url：$url\n";

    # 1では無い場合は処理終了
    return if $app->param('line_notify_check') ne 1;

    if ( $app->param('revision-note') ) {
        $message .= "変更メモ：" . $app->param('revision-note') . "\n";
    }

    # 新規作成された記事か更新された記事かを判断
    if ( $created_on eq $modified_on ) {

        # 記事が新規作成された場合の処理
        $message .= "記事を新規作成しました。";
    }
    else {
        # 記事が更新された場合の処理
        $message .= "記事を更新しました。";
    }

    my $data = MT::PluginData->load( { plugin => 'MtLineNotifyPost' } );
    # dataがなければ終了
    return unless $data;

    my $big_data_structure = $data->data;
    my $ua                 = LWP::UserAgent->new;
     # ここにLINE Notifyトークンを設定
    my $token              = $big_data_structure->{line_token};

    my $res = $ua->post(
        "https://notify-api.line.me/api/notify",
        'Content-Type'  => 'application/x-www-form-urlencoded',
        'Authorization' => "Bearer $token",
        Content         => [
            message => $message
        ]
    );

     MT->log(
            {
                message => $token,
            }
        );

    if ( !$res->is_success ) {
        MT->log(
            {
                message => "メッセージの送信に失敗しました:" . $res->status_line,
            }
        );
    }
}

sub template_source_footer {
    my ( $cb, $app, $tmpl ) = @_;
    my $plugin = MT->component('MtLineNotifyPost');

    my $path = $plugin->get_config_value('filepath');
    $path = MT->config->FilePath if MT->config->FilePath;
    ( $path = $app->base ) =~ s!https?://!! unless $path;
    $path = trim($path);

    return
      unless $path && $app->mode eq "view" && $app->param('_type') eq "entry";

    my $position = quotemeta(q{</body>});
    my $plugin_tmpl =
      File::Spec->catdir( $plugin->path, 'tmpl', 'insert.tmpl' );
    my $insert = qq{<mt:include name="$plugin_tmpl" component="sample">\n};
    $$tmpl =~ s/($position)/$insert$1/;
}
1;
