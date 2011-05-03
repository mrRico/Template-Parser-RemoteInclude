package Template::Parser::RemoteInclude;

use strict;
use warnings;

our $VERSION = '0.01';

use AnyEvent;
use AnyEvent::Curl::Multi;
use HTTP::Request;
use Scalar::Util qw(refaddr);
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
    my ($class, $param) = @_;
    
    my $self = $class->SUPER::new($param);
    $self->{iparam} = $param;
    $self->{aecm} = AnyEvent::Curl::Multi->new(%$param);
    #$self->{ae} = AnyEvent->condvar;
    
    return $self;
}

sub _parse {
    my ($self, $tokens, $info) = @_;
    
    $DB::signal = 1;
    
#    use LWP;
#    my $ua = LWP::UserAgent->new;
#    my $res = $ua->get('http://www.yandex.ru/');
#    
#    $tokens->[0] = [
#           '"foo"',
#           1,
#           $self->split_text($res->content)
#    ];
    
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
        my $req = HTTP::Request->new(GET => eval($tokens->[$_]->[2]->[3]));
        my $addr = refaddr($req);
        $ids_rinclude->{$_} = $addr;  
        ($addr => $req); 
    } @ids_rinclude;
    
    # зарегистрируем запросы в Curl::Multi
    my @handler_cm = map {$self->{aecm}->request($_)} values %requests;
    
    # колбэчимся и в колбэке переопределяем значения в %requests
    $self->{aecm}->reg_cb(response => sub {
        my ($client, $request, $response, $stats) = @_;
        $requests{refaddr($request)} = join '', $request->uri,'   ',$response->status_line;
    });
      
    $self->{aecm}->reg_cb(error => sub {
        my ($client, $request, $errmsg, $stats) = @_;
        $requests{refaddr($request)} = $errmsg;
    });
    
    # поднимаем событие обхода для Curl::Multi
    $self->{timer_w} = AE::timer(0, 0.04, sub { $self->{aecm}->_perform });
    
    # погнали
    $_->cv->recv for @handler_cm;
    
    # replace tokens RINCLUDE to simple value
    for (@ids_rinclude) {
        $tokens->[$_] = [
           "'".$ids_rinclude->{$_}."'", # unic name - addr
           1,
           $self->split_text($requests{$ids_rinclude->{$_}})
        ];
    }

    
#    my $req = HTTP::Request->new(GET => eval($tokens->[0]->[2]->[3]));
#    my $req_cm = $self->{aecm}->request($req);
#    
#    my $res;
#      $self->{aecm}->reg_cb(response => sub {
#          my ($client, $request, $response, $stats) = @_;
#          $res = $response;
#      });
#      
#      $self->{aecm}->reg_cb(error => sub {
#          my ($client, $request, $errmsg, $stats) = @_;
#          die $errmsg,"\n";
#      });
#    
#    $self->{timer_w} = AE::timer(0, 0.04, sub { $self->{aecm}->_perform });
#    $req_cm->cv->recv;
#    
#    $tokens->[0] = [
#           '"foo"',
#           1,
#           $self->split_text($res->content)
#    ];
    
    
#    my $i = 0;
#    my @ids_rinclude = grep {defined $_} map {
#        (
#            UNIVERSAL::isa($_->[2],'ARRAY') and
#            $_->[2]->[1] and
#            not ref $_->[2]->[1] and 
#            $_->[2]->[1] eq 'RINCLUDE' and
#            $_->[2]->[3] # url
#         ) ? $i++ : undef
#    } @$tokens;
#    
#    use HTTP::Request;
#    my $ids_rinclude = {};
#    my %requests = map {
#        my $req = HTTP::Request->new(GET => $tokens->[$_]->[2]->[3]);
#        my $addr = refaddr($req);
#        $ids_rinclude->{$_} = $addr;  
#        ($addr => $req); 
#    } @ids_rinclude;
#    
#      #my @hand = map {$self->{aecm}->request($_)} values %requests;
#      #my $request1 = HTTP::Request->new(GET => 'http://www.yandex.ru/');
#      $self->{aecm}->request([values %requests]);
#    
#      $self->{aecm}->reg_cb(response => sub {
#          my ($client, $request, $response, $stats) = @_;
#          $requests{refaddr($request)} = join '', $request->uri,'   ',$response->status_line;
#          #sleep 1;
#          #$i--;
#          #undef $client unless $i;
#          #print Dumper($stats),"\n";
#          #$handle->cv()->recv;
#          #$client->destroy;
#      });
#      
#  $self->{aecm}->reg_cb(error => sub {
#      my ($client, $request, $errmsg, $stats) = @_;
#      print $errmsg,"\n";
#  });
#      
#    $self->{aecm}->start;
#    #$self->{timer_w} = AE::timer(0, 0.04, sub { $self->{aecm}->_perform });
#    #$_->cv->recv for @hand;
#    
#    my $client = delete $self->{aecm};
#    undef $client;
#    
#    # re-init AnyEvent::Curl::Multi for next _parse
#    $self->{aecm} = AnyEvent::Curl::Multi->new(%{$self->{iparam}});
#    
#    # replace tokens RINCLUDE to simple value
#    for (@ids_rinclude) {
#        $tokens->[$_] = [
#           $ids_rinclude->{$_}, # unic name - addr
#           1,
#           [
#            'LITERAL',
#            $requests{$ids_rinclude->{$_}}
#           ]
#        ];
#    }
    
    return $self->SUPER::_parse($tokens, $info);
}


1;
__END__
