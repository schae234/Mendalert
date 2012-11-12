#!/usr/bin/perl

package csbio::Mendalert;
use strict;
use warnings;

my $DEBUG = shift || 0;

# We need to include these directories so it works when we cron it
BEGIN{
    push @INC, (
        '/opt/csw/lib/perl/site_perl',
        '/opt/csw/share/perl/site_perl',
        '/opt/csw/share/perl/site_perl',
        '/opt/csw/lib/perl/csw',
        '/opt/csw/share/perl/csw',
        '/opt/csw/share/perl/csw',
        '/opt/csw/lib/perl/5.10.1',
        '/opt/csw/share/perl/5.10.1',
    );
}


use MIME::Lite;
use Mail::Sendmail;
use LWP::Simple;
use JSON;
use pQuery;

sub decode_json_from_file{
    local $/;
    open my $json_file, '<', $_[0]; 
    my $ds = decode_json(<$json_file>);
    close($json_file);
    return $ds;
}
sub encode_json_to_file{
    my $ds = $_[0]; 
    open my $json_file, '>', $_[1]; 
    print $json_file encode_json($ds) or die $!;
    close($json_file);
}

my $wd = "/home/schaefer/mendalert/";

my $old_ds = decode_json_from_file($wd."group_info.json") or die $!;
my $emails = decode_json_from_file($wd."emails.json")     or die $!;
my $keys = decode_json_from_file($wd."tokens.json") or die $!;

my $ds = decode_json(get("http://api.mendeley.com/oapi/documents/groups/$keys->{'group_id'}/docs/?consumer_key=".$keys->{'consumer_key'})) or die $!;

if($old_ds->{"total_results"} < $ds->{'total_results'}){
    # There is a new Paper!
    # Fetch the group info HTML
    # And Send the Email!
    my $msg = MIME::Lite->new(
        From    => 'schae234@umn.edu',
        To      => join(",",@$emails),
        Cc      => '',
        Subject => 'New Paper Added To Mendeley',
        Type    => 'multipart/mixed',
    );
    # Fetch the feed
    my $html = pQuery("http://www.mendeley.com/groups/2346321")
                        ->find("#group-overview-feed-block")
                        ->toHtml(); 
    $html =~ s/style=".*"/style=""/g;
    $msg->attach(
        Type => 'text/html',
        Data => '
                <body>
                    There has been a new paper posted to csbio!<br />
                    <a href="http://www.mendeley.com/groups/2346321/csbio/">Check it out here!</a><br /><br/>'
                    .$html.
                '</body>'
    );
    $msg->send;
    # Update the local database!
    encode_json_to_file($ds,'/home/schaefer/mendalert/group_info.json');
}
# This is the end folks

exit;
