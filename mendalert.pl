#!/usr/bin/perl

package csbio::Mendalert;
use strict;
use warnings;
use Getopt::Long;
use MIME::Lite;
use Mail::Sendmail;
use LWP::Simple;
use JSON;
use pQuery;
use Data::Dumper;
use feature qw(say);

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

my $DEBUG   = 1;
my $VERBOSE = 0;
my $FORCE   = 0;

GetOptions(
    'debug' => \$DEBUG,
    'verbose' => \$VERBOSE,
    'force'   => \$FORCE,
);

sub main{
    # load a working directory, we're not sure where perl is being executed from
    my $wd = "/heap/lab_website/mendalert/";
    # load in previously loaded group info (this might need to be preloaded or the script wont execute at first
    my $old_ds = decode_json_from_file($wd."group_info.json") or die $!;
    # loads an email list, its just an array of emails
    my $emails = $DEBUG ? ['schae234@umn.edu'] : decode_json_from_file($wd."emails.json") or die $!;
    # we need API keys from mendeley so we can grab stuff over the API
    my $keys = decode_json_from_file($wd."tokens.json") or die $!;
    # Do a get request and transform the json the perl data structures
    my $ds = decode_json(get("http://api.mendeley.com/oapi/documents/groups/$keys->{'group_id'}/docs/?consumer_key=".$keys->{'consumer_key'})) or die $!;
    # Check yourself
    if($DEBUG){
        say Dumper({
            "Working in" => $wd,
            "Emailing:"  => $emails,
            "Old Info"   => $old_ds,
            "Mendaley Info: " =>$ds
        })
    }
    # do we have more papers now than we did last time?
    # Are we forceing an email to go through?
    if($FORCE or
       $old_ds->{"total_results"} < $ds->{'total_results'}){
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
        print STDERR "Emailing ".join(", ", @$emails) if $VERBOSE;
        # Fetch the feed, its public. We might as well make it pretty
        my $html = pQuery("http://www.mendeley.com/groups/$keys->{'group_id'}")
                            ->find("#group-overview-feed-block")
                            ->toHtml(); 
        # using regex to edit the html is naughty. but whatevs.
        $html =~ s/style=".*"/style=""/g;
        # send an email with html
        $msg->attach(
            Type => 'text/html',
            Data => '
                    <body>
                        There has been a new paper posted to csbio!<br />
                        <a href="http://www.mendeley.com/groups/2346321/csbio/">Check it out here!</a><br /><br/>'
                        .$html.
                    '</body>'
        );
        $msg->send || die "Could not send Email";
        # Update the local database!
        encode_json_to_file($ds,$wd.'group_info.json');
    }
    return 0;
}
# This is the end folks
exit main() ? 0 : 1;

# Helper Functions
sub decode_json_from_file{
    local $/;
    open my $json_file, '<', $_[0]; 
    my $ds = decode_json(<$json_file>);
    return $ds;
}
sub encode_json_to_file{
    my $ds = $_[0]; 
    open my $json_file, '>', $_[1]; 
    print $json_file encode_json($ds) or die $!;
}
