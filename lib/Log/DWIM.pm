package Log::DWIM;

our $VERSION = '0.001_001';

use strict;
use warnings;
no warnings 'uninitialized';

use File::Basename;
use Carp qw(confess longmess);
use Log::Log4perl qw(:easy);

use parent qw(Exporter);
our @EXPORT = qw(init_logging);

sub import {

    my $caller = caller();

    eval qq{
        package $caller;
        use Log::Log4perl qw(:easy);
    };
    die $@ if $@;

    Log::DWIM->export_to_level( 1, @_ );
}

my $log_config_template;

init_logging();

# TODO use STDERR if LOG_FILE set?

# may also be called by external module to reinitialize
sub init_logging {
    my (%p) = @_;

    my $log_level      = $p{log_level}      || $ENV{LOG_LEVEL};
    my $log_file       = $p{file}           || $ENV{LOG_FILE};
    my $log_level_file = $p{file_log_level} || $ENV{FILE_LOG_LEVEL} || "INFO";
    my $log_pattern     = "%d{HH:mm} %-5p> %m%n";
    my $screen_appender = "Log::Log4perl::Appender::Screen";

    my $new_config;

    if ( !$log_config_template ) {

        local $/;
        $log_config_template = <DATA>;
    }

    # if connected to a terminal
    if ( -t STDERR && !$log_level ) {
        $log_level       = "INFO";
        $screen_appender = "Log::Log4perl::Appender::ScreenColoredLevels";
    }

    $log_level ||= "ERROR";
    $log_level = uc $log_level;

    if ( $log_level eq "TRACE" ) {
        $log_pattern = "%d [%P] %-5p %F %L %M> %m%n";
    }

    my $file_logger;
    if ($log_file) {

        if ( $log_file eq 1 ) {
            $log_file = "~/log/" . basename($0) . ".log";
        }

        $log_file =~ s/^~/$ENV{HOME}/g;
        $file_logger = ", file";
    }

    $log_file ||= "/dev/null";

    $new_config = $log_config_template;
    $new_config =~ s/LOG_LEVEL_STDERR/$log_level/gm;
    $new_config =~ s/LOG_PATTERN_STDERR/$log_pattern/gm;
    $new_config =~ s/LOG_LEVEL_FILE/$log_level_file/gm;
    $new_config =~ s/LOG_FILE/$log_file/gm;
    $new_config =~ s/FILE_LOGGER/$file_logger/gm;
    $new_config =~ s/SCREEN_APPENDER/$screen_appender/gm;

    my $log4perl_conf = $ENV{LOG4PERL_CONF};
    if ($log4perl_conf) {
        open( F, $log4perl_conf ) or die $!;
        $new_config .= <F>;
        close(F);
    }

    Log::Log4perl->init( \$new_config );
}

# route output of die and warn into log4perl
{

    # msg needs trailing \n otherwise stacktrace is automatically extended
    # with the location of the error

    # http://log4perl.sourceforge.net/releases/
    # Log-Log4perl/docs/html/Log/Log4perl/FAQ.html#42a83
    $SIG{__DIE__} = sub {
        my ($msg) = @_;

        # If we're in an eval {} and might want to catch the error
        return if $^S;

        # remove duplicate line information from message string
        $msg =~ s/at\s\S+\sline\s\d+(\.|, \<.+?> line \d+\.)*$//g;
        $msg =~ s/\n+$/\n/g;

        local $Carp::CarpLevel;
        $Carp::CarpLevel++;
        Log::Log4perl::get_logger()->fatal( $msg . "    " . longmess() );

        # suppress already logged STDERR
        open STDERR, ">/dev/null";

        confess $msg;
    };

    $SIG{__WARN__} = sub {
        my ($msg) = @_;

        $msg =~ s/ at\s\S+\sline\s\d+\.$//g;
        $msg =~ s/\n+$/\n/g;

        $msg .= "    " . longmess()
            if $ENV{LOG_LEVEL} =~ /trace/i;

        local $Log::Log4perl::caller_depth;
        $Log::Log4perl::caller_depth++;
        Log::Log4perl::get_logger()->warn($msg);
    };
}

1;

__DATA__
### Log4perl default config ####################################################

#== root =======================================================================
log4perl.logger = TRACE, stderr FILE_LOGGER

#== stderr =====================================================================
log4perl.appender.stderr.Threshold = LOG_LEVEL_STDERR
log4perl.appender.stderr           = SCREEN_APPENDER
log4perl.appender.stderr.color.TRACE =
log4perl.appender.stderr.color.DEBUG =
log4perl.appender.stderr.color.INFO = GREEN
log4perl.appender.stderr.color.WARN = MAGENTA
log4perl.appender.stderr.color.ERROR = RED
log4perl.appender.stderr.color.FATAL = RED
log4perl.appender.stderr.stderr    = 1
log4perl.appender.stderr.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.stderr.layout.ConversionPattern = LOG_PATTERN_STDERR

#== file ======================================================================
log4perl.appender.file.Threshold = DEBUG
log4perl.appender.file           = Log::Dispatch::FileRotate
log4perl.appender.file.filename  = LOG_FILE
log4perl.appender.file.mode      = append
log4perl.appender.file.max       = 31
# rotate every day at 0:00
log4perl.appender.file.DatePattern = 0:0:0:1*0:0:0
log4perl.appender.file.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.file.layout.ConversionPattern = %d [%P] %-5p %F %L %M> %m%n

#== special classes ============================================================
# avoid undefined warnings from log4perl (see warning trap above)
log4perl.logger.Log::Log4perl = ERROR

### END ########################################################################
__END__
