package Plagger::Plugin::CustomFeed::TumblrV2;
use strict;
use warnings;
use feature qw( say );
use base qw( Plagger::Plugin );
use Encode;
use DB_File;
use lib qw(/home/toshi/perl/lib);
use TumblrDashboardV2;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'subscription.load' => \&load,
    );
}

sub load {
    my($self, $context) = @_;
    my $feed = Plagger::Feed->new;
    $feed->aggregator(sub { $self->aggregate($context) });
    $context->subscription->add($feed);
}

sub get_dashboard {
    my($self, $context, $args) = @_;

		my $pit_account = $self->conf->{pit_account};
		my $td = TumblrDashboardV2->new($pit_account);

		my $since_id;
		my $dir = $self->conf->{dir} || '.';
		my $read_pit = $dir . '/' . 'read.pit'; 
		open my $fh, '<', $read_pit or warn 'read.pit not exist';
		while (<$fh>) {
			chomp;
			$since_id = $_ ;
		}				
		close $fh;

		my $limit					= $self->conf->{limit} || 50; 
		my $offset				= $self->conf->{offset} || 0;
		$since_id			= $self->conf->{since_id} || $since_id ||  35000000000; 
		my $type					= $self->conf->{type} || '';
		my $reblog_info		= 'true';
		my $note_info			= $self->conf->{note_info}	|| 'false';	
		say $since_id;
		my %opt = (
				'limit' => $limit,
				'offset' => $offset,
				'since_id'		=> $since_id,
				'type'	=> $type,
				'reblog_info' => $reblog_info,
				'note_ifo' => $note_info,
		);

		$td->set_option(%opt);
		my $res = $td->get_hash;		
		if ($td->_err) {
#			$context->log(info => 'no contets');
			die 'no contets';
		}

		for my $var (@$res) {
			my $since_id_tmp = $var->{id};
			if ($since_id < $since_id_tmp) {
				$since_id = $since_id_tmp;
			}
		}

		open $fh, '+>', $read_pit; #or die 'read.pit not exist';
		print $fh $since_id."\n";
		close $fh;
#		$context->log(info => "read count is  $since_id");
		return $res;
}

sub aggregate {
    my ($self, $context ) = @_;

    my $feed = Plagger::Feed->new;
		$feed->link('http://tumblr.com');
    $feed->type('Tumblr.Dashboard');
    $feed->title("Tumblr Dashboard"); 
    $feed->id('Tumblr:Dahboard'); 

		my $res = $self->get_dashboard;

		my $dbname = '~/.plagger/tumblr_deduped_check';
		my %deduped;
		dbmopen(%deduped, $dbname, 0644);
		my $deduped =\%deduped;

		for my $post (@$res){
			my $entry = Plagger::Entry->new;

			my $id = $post->{id};
			if (exists $deduped{$id}){
				$context->log( debug => "$id match an old post");
				next;
			}else {
#				my $id = $post->{id};
				my $date = $post->{date};
				my $publish_type = $post->{type};
				my $title = $post->{source_title} || $post->{title} || $post->{blog_name} || undef;
				my $link =  $post->{photos}->[0]->{orginal_size}->{url} || $post->{link_url} || $post->{source_url} || $post->{post_url};
				my $text =   $post->{caption} || $post->{body};
					
				$deduped{$id} = $link;

				decode_utf8($title);
				decode_utf8($text);

				$title =~ s/<.+?>//gs;

		  	$entry->title($title);
			  $entry->link($link);
			  $entry->body($text);
			  $entry->date($date);
				$feed->add_entry($entry);
     	}
		}
	$context->update->add($feed);
}
1;

__END__

=head1 NAME

Plagger::Plugin::CusiomFeed::Tumblr

=head1 SYNOPSIS

  - module: CustomFeed::Tumblr
    config:
     put_account: YOUR PIT ACCOUNT
     limit: 50
     type: 'text'
     offset: 0
     

=head1 AUTHOR

Toshi Azwad

=cut
