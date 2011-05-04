#!/usr/bin/perl
use strict;
use warnings;

use lib 'lib';

use Template;
use Template::Parser::RemoteInclude;


my $tt = Template->new(
 INCLUDE_PATH => '/home/mrrico',
 PARSER => Template::Parser::RemoteInclude->new(
     'Template::Parser' => {},
     'AnyEvent::Curl::Multi' => {
        max_concurrency => 10
     }
 ),
 WRAPPER => 'dummy.tt2'
 
);

#my $tmpl = '[% INCLUDE dummy.tt2 %][% RINCLUDE \'http://ya.ru/\' %][% SET foo = 34 %]';
#my $tmpl1 = "
#    [% RINCLUDE 'http://ya.ru/' %]
#    [% RINCLUDE 'http://search.cpan.org/~abw/Template-Toolkit-2.22/lib/Template/Parser.pm' %]
#    [% RINCLUDE 'http://mailliste111.ru/' %]
#    ";
#my $tmpl2 = "[% 'blahh' %]\nNOOOO [% foo %]";
#my $tmpl3 = "[% RINCLUDE GET \'http://ya.ru/\'    ['head1' => 'val1', 'head2' => 'val2']    'come content' %]";
my $tmpl3 = "[% SET CSS = [] %][% RINCLUDE url %]";

#print "88888888888888\n";
#$tt->process(\$tmpl,{});
#print "88888888888888\n";
#$tt->process(\$tmpl1,{});
#print "88888888888888\n";
#$tt->process(\$tmpl2,{});
#print "88888888888888\n";
$tt->process(\$tmpl3,{url => HTTP::Request->new(GET => 'http://ya.ru/'), name => 'User'});



#  use AnyEvent; # not AE
#  
#  my @pr = (11,12,13);
#    
#   my $cv = AnyEvent->condvar;
#   my $wait_one_and_a_half_seconds = AnyEvent->timer (
#      after => 0,  # after how many seconds to invoke the cb?
#      interval => 1,
#      cb    => sub { # the callback to invoke
#         $cv->send if (not @pr or $pr[0] == 12);
#         print shift @pr, "\n";
#         #sleep 1;
#      },
#   );
#   $cv->recv;
#   print "EEEddd\n"; 
    
   # can do something else here

   # now wait till our time has come
   


exit;
__DATA__
