#!/usr/bin/perlml
use strict;
use warnings;
use Redmine::API;
use Config::Tiny;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use IO::All;
use Log::Log4perl qw(get_logger :levels);

# Initialize logging
Log::Log4perl->init($ENV{HOME} . '/etc/logging.conf');
my $logger = get_logger();

# Read configuration
my $config = Config::Tiny->read($ENV{HOME} . '/etc/config.ini');
if (!defined $config) {
    $logger->fatal("Failed to read config file: $!");
    die "Failed to read config file: $!";
}
my $api_key = $config->{Redmine}->{api_key};
my $tracker_id = $config->{Redmine}->{tracker_id};
my $url = $config->{Redmine}->{url};

if (!defined $api_key || !defined $tracker_id || !defined $url) {
    $logger->fatal("API key, tracker ID, or URL not found in config file");
    die "API key, tracker ID, or URL not found in config file";
}

# Set up Redmine client
my $redmine = Redmine::API->new(
    url    => $url,
    api_key => $api_key
);

# Function to create a ticket in Redmine
sub create_ticket {
    my ($project_id, $subject, $description) = @_;

    my $issue;
    eval {
        $issue = $redmine->issue->create(
            project_id  => $project_id,
            subject     => $subject,
            description => $description,
            tracker_id  => $tracker_id,
            status_id   => 1    # Adjust as needed
        );
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
    return ($project_id, $subject, $body);
}

# Read email from standard input
my $email = io('-')->all;

$logger->info("Reading email from standard input");

# Parse email
my ($project_id, $subject, $description) = parse_email($email);

if (!defined $project_id) {
    $logger->fatal("Project ID could not be extracted from the email address");
    die "Project ID could not be extracted from the email address";
}

# Create ticket in Redmine
my $ticket_id;
eval {
    $ticket_id = create_ticket($project_id, $subject, $description);
};

if ($@) {
    $logger->fatal("Failed to create ticket: $@");
    die "Failed to create ticket: $@";
}

$logger->info("Created ticket with ID: $ticket_id");

