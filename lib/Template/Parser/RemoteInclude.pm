package Template::Parser::RemoteInclude;

use strict;
use warnings;

our $VERSION = '0.01';

use namespace::autoclean;
use AnyEvent;
use AnyEvent::Curl::Multi;
use HTTP::Request;
use Scalar::Util qw(refaddr);
use Try::Tiny;
use base 'Template::Parser';

=head1 NAME

Template::Parser::RemoteInclude

=head1 DESCRIPTION

=head1 SYNOPSIS


=head1 METHODS

=head2 new(%param)

Simple constructor

=cut
sub new {
    my ($class, %param) = @_;
    
    my $self = $class->SUPER::new($param{'Template::Parser'});
    $self->{iparam} = $param{'AnyEvent::Curl::Multi'} || {};
    $self->{aecm} = AnyEvent::Curl::Multi->new(%{$self->{iparam}});
    
    return $self;
}

sub _parse {
    my ($self, $tokens, $info) = @_;
    $self->{ _ERROR } = '';
    
    $DB::signal = 1;
    
    # выгребем все id элементов массива с RINCLUDE и url в качесвте первого аргумента
    my @ids_rinclude = ();
    for (0..$#$tokens) {
        if (
            UNIVERSAL::isa($tokens->[$_],'ARRAY') and
            UNIVERSAL::isa($tokens->[$_]->[2],'ARRAY') and
            $tokens->[$_]->[2]->[1] and
            not ref $tokens->[$_]->[2]->[1] and 
            $tokens->[$_]->[2]->[1] eq 'RINCLUDE' and
            $tokens->[$_]->[2]->[3] # url
        ) {
            push @ids_rinclude, $_;
        }
    }
    
    # хэш-связка: id элемента в массиве -> ссылка в памяти
    my $ids_rinclude = {};
    # наполним хэш: ссылка в памяти -> объект запроса
    my %requests = map {
        (my $url = $tokens->[$_]->[2]->[3]) =~ /^(['"])/;
        $url =~ s/(^$1|$1$)//g if $1;
        $self->debug("found RINCLUDE for url: $url") if $self->{ DEBUG };
        my $req = HTTP::Request->new(GET => $url);
        my $addr = refaddr($req);
        $ids_rinclude->{$_} = $addr;  
        ($addr => $req); 
    } @ids_rinclude;
    
    # зарегистрируем запросы в Curl::Multi
    my @handler_cm = map {$self->{aecm}->request($_)} values %requests;
    
    # колбэчимся и в колбэке переопределяем значения в %requests
    $self->{aecm}->reg_cb(response => sub {
        my ($client, $request, $response, $stats) = @_;
        #$requests{refaddr($request)} = $response->content;
        #$requests{refaddr($request)} = join '', $request->uri,'   ',$response->status_line;
        $requests{refaddr($request)} = $request->uri =~ /ya\.ru/ ? '[% SET eb = 12 %]Blahh! [% eb %]'."\n[% RINCLUDE 'http://search.cpan.org/~abw/Template-Toolkit-2.22/lib/Template/Parser.pm' %]\n" : join '', $request->uri,'   ',$response->status_line;
    });
      
    $self->{aecm}->reg_cb(error => sub {
        my ($client, $request, $errmsg, $stats) = @_;
        $self->debug("error returned RINCLUDE for url: ".$request->uri." - $errmsg") if $self->{ DEBUG };
        $self->error("RINCLUDE for url: ".$request->uri." - $errmsg");
        #$requests{refaddr($request)} = $errmsg;
    });
    
    # поднимаем событие обхода для Curl::Multi
    $self->{timer_w} = AE::timer(0, 0, sub { $self->{aecm}->_perform }) if (@handler_cm and not $self->{timer_w});
    
    # погнали (see AnyEvent::Curl::Multi)
    for my $crawler (@handler_cm) {
         try {
            $crawler->cv->recv;
        } catch {
            $self->debug("error returned RINCLUDE for url: ".$crawler->{req}->uri." - $_") if $self->{ DEBUG };
            $self->error("RINCLUDE for url: ".$crawler->{req}->uri." - $_");
            #$requests{refaddr($crawler->{req})} = $_;
        };
    };
    
    return if $self->{ _ERROR };
    
#    # replace tokens RINCLUDE to simple value
#    for (@ids_rinclude) {
#        $tokens->[$_] = [
#           "'".$ids_rinclude->{$_}."'", # unic name - addr
#           1,
#           $self->split_text($requests{$ids_rinclude->{$_}})
#        ];
#    }

    # extend tokens RINCLUDE to new array values from request
    for (@ids_rinclude) {
        my $parse_upload = $self->split_text($requests{$ids_rinclude->{$_}});
        my $added_len = $#$parse_upload;
        splice(@$tokens, $_, 1, @$parse_upload); 
        $_ += $added_len for @ids_rinclude;
    }
    
    # методично, как тузик тряпку, продожаем обработку токенов, пока не исчерпаем все RINCLUDE, если они пришли в контенте ответов
    return @ids_rinclude ? $self->_parse($tokens, $info) : $self->SUPER::_parse($tokens, $info);
}


1;
__END__
