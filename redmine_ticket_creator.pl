#!/usr/bin/perlml
use strict;
use warnings;
use Redmine::API;
use Config::Tiny;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use IO::All;
use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;

# Initialize logging
Log::Log4perl->init('logging.conf');
my $logger = get_logger();

# Read configuration
my $config = Config::Tiny->read('config.ini');
if (!defined $config) {
    $logger->fatal("Failed to read config file: $!");
    die "Failed to read config file: $!";
}
$logger->info("Config file read successfully");

my $api_key = $config->{Redmine}->{api_key};
my $tracker_id = $config->{Redmine}->{tracker_id};
my $base_url = $config->{Redmine}->{url};  # Renamed to base_url for consistency

$logger->info("API Key: $api_key");
$logger->info("Tracker ID: $tracker_id");
$logger->info("Base URL: $base_url");

if (!defined $api_key || !defined $tracker_id || !defined $base_url) {
    $logger->fatal("API key, tracker ID, or base URL not found in config file");
    die "API key, tracker ID, or base URL not found in config file";
}

# Set up Redmine client
$logger->info("Setting up Redmine client with Base URL: $base_url and API Key: $api_key");
my $redmine = Redmine::API->new(
    base_url => $base_url,
    auth_key => $api_key
);

$logger->info("Redmine client setup successful");

# Function to create a ticket in Redmine
sub create_ticket {
    my ($project_id, $subject, $description) = @_;

    my $issue;
    eval {
        $logger->info("Creating ticket with Project ID: $project_id, Subject: $subject");
        $issue = $redmine->issue->create(
            project_id  => $project_id,
            subject     => $subject,
            description => $description,
            tracker_id  => $tracker_id,
            status_id   => 1    # Adjust as needed
        );
        $logger->info("Redmine response: " . Dumper($issue));
    };

    if ($@) {
        $logger->error("Failed to create ticket: $@");
        die "Failed to create ticket: $@";
    }

    $logger->info("Ticket created with ID: " . $issue->{id});
    return $issue->{id};
}

# Function to parse email and extract subject, body, and project ID
sub parse_email {
    my ($email) = @_;

    my $parsed_email = Email::MIME->new($email);
    my $subject = $parsed_email->header('Subject');
    my $body = $parsed_email->body_str;

    # Extract project ID from "To" email address
    my $to = $parsed_email->header('To');
    my ($project_id) = $to =~ /\+([^@]+)@/;

    $logger->info("Parsed email with subject: $subject and project ID: $project_id");
    return ($project_id, $subject, $
