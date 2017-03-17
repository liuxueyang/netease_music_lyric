#!/usr/bin/perl

# 2016/12/29 10:14:03

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies;
use JSON::Parse ':all';
use JSON qw(decode_json);
use Data::Dumper;
use File::HomeDir;
use Path::Class;

# don't forget to use -SC command option

my $ua = LWP::UserAgent->new;

# Define user agent type
$ua->agent('Mozilla/8.0');

# 提交給服務器的搜索的名字
my $search_name;

# 歌詞原文的歌詞文件名
my $lyric_file_name;

# 歌詞翻譯的歌詞文件名
my $another_lyric_file_name;

# 歌詞原文和翻譯的歌詞文件名
my $all_in1_lyric_file_name;

# 提交給服務器的歌曲id，通過搜索歌曲名字返回結果得到。（如果有返回結果
# 的話：1.歌曲不存在，搜索不到。2.搜索失敗）

my $id;

my $search_action = 'http://music.163.com/api/search/get/web';

# 搜索，服務器返回值
my $search_res;

my ($musicD, $lyricD, $musicDir, $lyricDir);

# music directory and lyric directory as command argument
if ($ARGV[0] && $ARGV[1]) {
    $musicDir = $ARGV[0];
    $lyricDir = $ARGV[1];

    print "musicDir = $musicDir, lyricDir = $lyricDir\n";

    $musicD = dir($musicDir);
    $lyricD = dir($lyricDir);
    
    chdir $musicD || die "can not change directory to $musicD";
    
    my @files = glob("*.mp3");
    for my $f (@files) {
	$f =~ s/\.mp3$//;
	$search_name = $f;
	$all_in1_lyric_file_name = $f . ".lrc";
	$lyric_file_name = $f . ".lrc";
	$another_lyric_file_name = $f . "-another-" . ".lrc";

	print $f, "\n";
	
	$search_res = search_song();
	next unless ($search_res);

	#print $lyric_file_name, "\n";

	my ($ids, $artist_names, $names, $cnt) = search_result(0);

	my $len=@$names;
	my $indice=0;
	# TODO regex unicode ?
	
#	for my $i (0..$len-1) {
#	    if ($names->[$i] =~ /$f/) { $indice = $i; last; }
#	}
	
	if ($cnt) {
	    # 参数中的0代表默认使用搜索结果列表中的第一个
#	    generate_lyric_filename($ids, $artist_names,
	    #				    $names, 0);
	    $id = $ids->[$indice];
	    get_lyric($names, $indice);
	}	
	else {
	    print "$search_name DOES NOT HAVE LYRIC.\n";
	}

	print "next\n";
    }
}
else {
    # User input song name
    $lyricDir = File::HomeDir->my_home . "/.lyrics";
    $lyricD = dir($lyricDir);

    print "Please enter the song name: ";
    chomp($search_name = <>);
    $search_res = search_song();
    
    exit 0 unless ($search_res);
    
    my ($ids, $artist_names, $names, $cnt) = search_result(1);
    
    if ($cnt)
    {
	print "\nInput indice of the song: ";
	my $input_id;
	chomp($input_id = <>);

	die "id is invalid" unless ($input_id >=0 && $input_id < $cnt);

	generate_lyric_filename($ids, $artist_names, 
				$names, $input_id);
	get_lyric($names, $input_id);
    }
    else {
	print "$search_name DOES NOT HAVE LYRIC.\n";
	exit 0;
    }
}

sub get_lyric {
    my ($names, $input_id) = @_;
    # Request object
    my $lyri = "http://music.163.com/api/song/lyric?lv=1&kv=1&tv=-1&id=";
    $lyri .= $id;

    my $req = GET $lyri;

    # Make the request
    my $res = $ua->request($req);

    if ($res->is_success) {
	my ($another_lyric_content, $lyric_content);
	my $translated = parse_json($res->decoded_content)->{tlyric};

	if ($translated) {
	    # 有翻译
	    $another_lyric_content = $translated->{lyric};
	}
	
	$lyric_content = parse_json($res->decoded_content)
	    ->{lrc}->{lyric};

	unless ($lyric_content || $another_lyric_content) {
	    print $names->[$input_id], " has no lyric online\n";
	}
	else {
	    write_lyric_file($lyric_content, $another_lyric_content, 0);
	}
    }
    else {
	print $res->status_line . "\n";
	exit 0;
    }
}

sub generate_lyric_filename {
    my ($ids, $artist_names, $names, $input_id) = @_;

    $id = $ids->[$input_id];
    my ($name, $artist) = ($names->[$input_id], 
			   $artist_names->[$input_id]);
    
    $lyric_file_name = $name . "-ori-by-" . $artist . ".lrc";
    
    $another_lyric_file_name = $name . "-another-by-" .
	$artist . ".lrc";
    
    $all_in1_lyric_file_name = $name . "-by-" .	$artist . ".lrc";
}

sub write_lyric_file {    
# mode 是一个标志，0表示是用户直接输入歌曲名字搜索，1是遍历目录自动生
# 成歌词
    my ($lyric_content, $another_lyric_content) = @_;
    my ($fh, @lyric1, @lyric2, @head, @lyric);

    # 歌词原文
    if ($lyric_content) {
	$fh = $lyricD->file($lyric_file_name);
	$fh->openw()->print($lyric_content);
	@lyric1 = $fh->slurp();
    }
    
    if ($another_lyric_content) {
	# 歌词翻译
	$fh = $lyricD->file($another_lyric_file_name);
	$fh->openw()->print($another_lyric_content);
	@lyric2 = $fh->slurp();
    }

    if ($lyric_content && $another_lyric_content) {
	@head = (shift @lyric1, shift @lyric2);
	# @lyric = @lyric2;
	# push @lyric, @lyric1;

	# should not just sort!!
	# @lyric1 is original lyric
	# @lyric2 is the translated version
	# lyric2 should better appear before lyric1

	my %lyric1_hsh;
	for (@lyric1) { $lyric1_hsh{$1} = $_ if (/\[(.*)\]/); }
	my %lyric2_hsh;
	for (@lyric2) { $lyric2_hsh{$1} = $_ if (/\[(.*)\]/); }
	
	# @lyric = sort { $a cmp $b } @lyric;
	unshift @lyric, @head;
	for (sort keys %lyric2_hsh) {
	    push @lyric, $lyric2_hsh{$_};
	    push @lyric, $lyric1_hsh{$_};
	}
	
	my @del_indices = reverse(grep { $lyric[$_] =~ /^ *$/ }
				  0..$#lyric);
	for my $i (@del_indices) { splice @lyric, $i, 1; }
	
	$lyricD->file($all_in1_lyric_file_name)->
	    openw()->print(join '', @lyric);
    }
}

sub search_result {
    # 返回歌曲id、名字、演唱者列表，和搜索结果数目

    # 是否要输出列表
    my $mode = shift;
    
    my $response = $search_res->decoded_content;
    my $data = parse_json($response);
    my $result = $data->{result};
    my $songs = $result->{songs};
    my $cnt = 0;
    
    # 搜索结果中的歌曲id
    my @ids;
    
    # 搜索结果中的演唱者
    my @artist_names;
    
    # 搜索结果中的歌曲名字
    my @names;

    # 从搜索结果得到歌曲id、歌曲列表和演唱者这三个列表。
    for my $i (@$songs) {
	push @ids, $i->{id};
	push @names, $i->{name};

	print $cnt, ".  ", $i->{id}, "\t\t\t\t", $i->{name}, "\t\t\t\t"
	    if $mode;
	
	my $artists = $i->{artists};
	my @artist_names_in_song;
	
	for my $name (@$artists) { # cant use @$i->{artists}
	    print $name->{name} if $mode;
	    push @artist_names_in_song, $name->{name};
	}
	my $artist_name = join '_', @artist_names_in_song;
	push @artist_names, $artist_name;
	print "\n" if $mode;
	$cnt++;
    }

    return (\@ids, \@names, \@artist_names, $cnt);
}

sub search_song {
    return $ua->post($search_action, [s	=> $search_name, 
			       type	=> 1, 
			       offset => 0, 
			       limit => 10],
	      'Accept'		=> '*/*',
	      'Accept-Encoding'	=> 'gzip,deflate,sdch',
	      'Accept-Language'	=> 'zh-CN,zh;q=0.8,gl;q=0.6,zh-TW;q=0.4',
	      'Connection'		=> 'keep-alive',
	      'Content-Type'	=> 'application/x-www-form-urlencoded',
	      'Host'		=> 'music.163.com',
	      'Referer'		=> 'http://music.163.com/search/',
	      'User-Agent'		=> 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.152 Safari/537.36');
    
}
