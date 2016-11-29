#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies;
use JSON::Parse ':all';
use JSON qw(decode_json);
use Data::Dumper;
use File::HomeDir;

# don't forget to use -SC command option

my $ua = LWP::UserAgent->new;

# Define user agent type
$ua->agent('Mozilla/8.0');

my $search_name;
print "Please enter the song name: ";
chomp($search_name = <>);
my $lyric_file_name = ""; # the song's original language
my $another_lyric_file_name = ""; # the translated song lyric
my $all_in1_lyric_file_name = ""; # the both of above
my $id;

my $search_action = 'http://music.163.com/api/search/get/web';
my $search_res = $ua->post($search_action, [s		=> $search_name, 
					    type	=> 1, 
					    offset	=> 0, 
					    limit	=> 10],
			   'Accept'		=> '*/*',
			   'Accept-Encoding'	=> 'gzip,deflate,sdch',
			   'Accept-Language'	=> 'zh-CN,zh;q=0.8,gl;q=0.6,zh-TW;q=0.4',
			   'Connection'		=> 'keep-alive',
			   'Content-Type'	=> 'application/x-www-form-urlencoded',
			   'Host'		=> 'music.163.com',
			   'Referer'		=> 'http://music.163.com/search/',
			   'User-Agent'		=> 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.152 Safari/537.36');
if ($search_res) {
    my $response = $search_res->decoded_content;
    my $data = parse_json($response);
    my $result = $data->{result};

    my $songs = $result->{songs};
    my $cnt = 0;
    my @ids;
    my @artist_names;
    my @names;
    for my $i (@$songs) {
	push @ids, $i->{id};
	push @names, $i->{name};
	print $cnt, ".  ", $i->{id}, "\t\t\t\t", $i->{name}, "\t\t\t\t";
	my $artists = $i->{artists};
	my @artist_names_in_song;
	for my $name (@$artists) { # cant use @$i->{artists}
	    print $name->{name};
	    push @artist_names_in_song, $name->{name};
	}
	my $artist_name = join '_', @artist_names_in_song;
	push @artist_names, $artist_name;
	print "\n";
	$cnt++;
    }
    print "\nInput indice of the song: ";
    my $input_id;
    chomp($input_id = <>);
    $id = $ids[$input_id];
    $lyric_file_name = $names[$input_id] . "-ori-by-" . $artist_names[$input_id] . ".lrc";
    $another_lyric_file_name = $names[$input_id] . "-another-by-" . $artist_names[$input_id] . ".lrc";
    $all_in1_lyric_file_name = $names[$input_id] . "-by-" . $artist_names[$input_id] . ".lrc";
}
else {
    print "failed";
    print $search_res->status_line . "\n";
}

exit 0 unless $lyric_file_name;

# Request object
my $lyri = "http://music.163.com/api/song/lyric?lv=1&kv=1&tv=-1&id=";
$lyri .= $id;

my $req = GET $lyri;

# Make the request
my $res = $ua->request($req);

# Check the response
if ($res->is_success) {
    my $another_lyric_content = parse_json($res->decoded_content)->{tlyric}->{lyric} if (parse_json($res->decoded_content)->{tlyric});
    my $lyric_content = parse_json($res->decoded_content)->{lrc}->{lyric};

    chdir File::HomeDir->my_home . "/.lyrics";
    
    if ($lyric_content) {
	open (FILE, ">", $lyric_file_name);
	print FILE $lyric_content, "\n";
	close FILE;
    }
    if ($another_lyric_content) {
	open (FILE, ">", $another_lyric_file_name);
	print FILE $another_lyric_content, "\n";
	close FILE;
    }
    if ($lyric_content && $another_lyric_content) {
	open (FILE, '>', $all_in1_lyric_file_name);
	open(my $fh, '<', $lyric_file_name);
	my @lyric1 = <$fh>;
	close $fh;
	open($fh, '<', $another_lyric_file_name);
	my @lyric2 = <$fh>;
	close $fh;
	my @head = (shift @lyric1, shift @lyric2);
	my @lyric = @lyric1;
	push @lyric, @lyric2;
	@lyric = sort { $a cmp $b } @lyric;
	unshift @lyric, @head;
	my @del_indices = reverse(grep { $lyric[$_] =~ /^ *$/ } 0..$#lyric);
	for my $i (@del_indices) { splice @lyric, $i, 1; }
	print join '', @lyric;
	print FILE join '', @lyric;
	close FILE;
    }
} else {
    print $res->status_line . "\n";
}

exit 0;
