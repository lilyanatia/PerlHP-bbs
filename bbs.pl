#!/usr/bin/env perl

BEGIN{
 use strict;
 require 'config.pl';
}
use PerlHP;
<%

 use DBI;
 use PerlHP::Utils;
 use Digest::SHA;

 use lib '.';

 my $has_encode=0;
 eval 'use Encode qw(decode)';
 $has_encode=1 unless $@;

 my $dbh;
 open_db();
 my $threads=get_threads();
 my %langs;

 BEGIN {
  our $lang;
  our $c_lang;
  $lang=$c_lang unless $lang;
  %langs=LANGS;
  if(!$lang){
   my @accept_langs=split(/[^a-z-]+/,$ENV{HTTP_ACCEPT_LANGUAGE});
   for(@accept_langs){
    if($langs{$_}){
     $lang=$_;
     last;
    }
   }
  }
  $lang=LANG_DEFAULT unless $langs{$lang};
  cookie('c_lang',$lang,time()+315360000);
  require "strings_$lang.pl";
 }

 our $task;

 if($task eq 'post'){
  die S_HAX if $ENV{REQUEST_METHOD} ne 'POST';
  our $thread;
  our $field1;
  our $field2;
  our $comment;
  our $title;
  our $name;
  our $link;
  our $file;
  die S_SPAM if $name or $link;
  $thread=0 unless $thread;
  make_post($thread,$field1,$field2,$comment,$title,$file);
 }else{
  my $thread=0;
  if($ENV{PATH_INFO}=~/^\/+([0-9]+)\/?/){
   $thread=$1;
  }
  my $sth;
  if($thread){
   $sth=$dbh->prepare('SELECT UNIX_TIMESTAMP(lastmod) FROM threads WHERE id=?;')
    or die S_DBERR;
   $sth->execute($thread) or die S_DBERR;
  }else{
   $sth=$dbh->prepare('SELECT UNIX_TIMESTAMP(lastmod) FROM threads ORDER BY '.
    'lastmod DESC LIMIT 1;') or die S_DBERR;
   $sth->execute() or die S_DBERR;
  }
  my($modified)=$sth->fetchrow_array();
  my $ifmod=parse_http_date($ENV{HTTP_IF_MODIFIED_SINCE});
  if($modified <= $ifmod){
   header('Status: 304 Not modified');
  }else{
   header('Content-Type: text/html; charset=utf-8');
   header('Date: '.make_date(time(),'http'));
   header('Last-Modified: '.make_date($modified,'http'));

%><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="<%= S_LANG %>" xml:lang="<%= S_LANG %>">
 <head>
  <title><%= TITLE %></title>
  <link rel="stylesheet" type="text/css" href="<%= expand_filename(STYLESHEET) %>" />
  <link rel="shortcut icon" type="image/x-ico" href="<%= expand_filename(FAVICON) %>" />
  <link rel="Alternate" media="handheld" type="application/xhtml+xml" href="<%= expand_filename('mobile.pl') %>" />
  <link rel="Alternate" media="handheld" type="text/vnd.wap.wml" href="<%= expand_filename('wml.pl') %>" />
  <script type="text/javascript" src="<%= expand_filename('bbs.js') %>"></script>
 </head>
 <body onload="init()">

<% if($ENV{HTTP_ACCEPT}=~/application\/vnd\.wap\.xhtml\+xml/){ %>

 <p><a href="<%= expand_filename('mobile.pl') %>"><%= S_MOBILE %></a></p>

<% }elsif($ENV{HTTP_ACCEPT}=~/text\/vnd\.wap\.wml/){ %>

 <p><a href="<%= expand_filename('wml.pl') %>"><%= S_MOBILE %></a></p>

<%

 }

 if($ENV{PATH_INFO}=~/\/subback\/?.*/){

%>

  <div id="navigation">
   <a href="<%= $ENV{SCRIPT_NAME} %>"><%= S_RETURN %></a>
  </div>

  <div id="allthreads">
<% full_thread_list() %>
  </div>

<% }elsif($ENV{PATH_INFO}=~/^\/+([0-9]+)\/+([lr0-9,\-]+)\/?.*/){ %>

  <div id="navigation">
   <a href="<%= $ENV{SCRIPT_NAME} %>"><%= S_RETURN %></a>
   |
   <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $1 %>"><%= S_ENTIRE %></a>
   |
   <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $1 %>/-100"><%= S_FIRST100 %></a>
   |
   <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $1 %>/l50"><%= S_LAST50 %></a>
  </div>

<% show_thread_posts($1,$2) %>


<% }elsif($ENV{PATH_INFO}=~/^\/+([0-9]+)\/?.*/){ %>

  <div id="navigation">
   <a href="<%= $ENV{SCRIPT_NAME} %>"><%= S_RETURN %></a>
   |
   <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $1 %>/-100"><%= S_FIRST100 %></a>
   |
   <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $1 %>/l50"><%= S_LAST50 %></a>
  </div>

<% show_thread($1) %>

<%

 }else{
  if(scalar(keys %langs)>1){

%>

  <div id="navigation">

<%

 my @langlinks;
 for(keys %langs){
  push @langlinks,"<a href=\"$ENV{SCRIPT_NAME}?lang=$_\">$langs{$_}</a>";
 }

%>

  <%= join(' | ',@langlinks) %>

  </div>

<% } %>

  <div id="threadlistbox">
   <p id="threadlist">

<% main_page_thread_list() %>

   </p>
   <p id="threadlistnav">
    <a href="#threadform"><%= S_NEWTHR %></a>
    |
    <a href="<%= $ENV{SCRIPT_NAME} %>/subback"><%= S_ALLTHR %></a>
   </p>
  </div>
  <div id="threads">

<% main_page_threads() %>

  </div>
  <form id="threadform" class="postform" method="post"
   action="<%= $ENV{SCRIPT_NAME} %>" enctype="multipart/form-data">
   <p>
    <input type="hidden" name="task" value="post" />
    <span style="display:none">
     <label for="name">Spam: </label>
     <input type="text" name="name" id="name" />
     <label for="link">Spam: </label>
     <input type="text" name="link" id="link" /><br />
    </span>
    <label for="field1"><%= S_NAME %></label>
    <input type="text" name="field1" id="field1" />
    <label for="field2"><%= S_LINK %></label>
    <input type="text" name="field2" id="field2" />
    <br />
    <label for="title"><%= S_TITLE %></label>
    <input type="text" name="title" id="title" />
    <input type="submit" value="<%= S_CREATETHR %>" /><br />
    <label for="comment"><%= S_COMMENT %></label><br />
    <textarea name="comment" rows="6" cols="60" id="comment"></textarea><br />
    <label for="file"><%= S_IMAGE %></label>
    <input type="file" name="file" id="file" />
   </p>
  </form>

<% } %>

  <p class="footer">
   - <% printf(S_POWERED,'<a href="https://github.com/hotaru2k3/perlhp">modified</a> <a href="http://wakaba.c3.cx/perlhp/">PerlHP</a>',
      SQL_DB_LINK) %>
   -
  </p>
 </body>
</html>

<%

  }
 }

 close_db();

 sub main_page_thread_list(){
  my $i=0;
  my $j=0;
  my $thread;
  for $thread (@$threads){
   last if $j>40;
   ++$j;
   my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=@$thread;
   my $href;
   $href='#t-'.($i+1) if $i<10;
   $href="$ENV{SCRIPT_NAME}/$id" if $i>9;
   ++$i;

%>

    <a href="<%= $ENV{SCRIPT_NAME}%>/<%= $id %>"><%= $i %></a>:<a
     href="<%= $href %>"><%= $title %>
      (<%= $postcount %>)</a><%= $i<@$threads?',':'' %>

<%

  }
 }

 sub main_page_threads(){
  my $thread;
  return if !@$threads;
  my $c=0;
  for $thread (@$threads){
   if(++$c<10){
    my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=@$thread;

%>

   <div class="<%= $permasaged?'permasaged':'' %>thread" id="t-<%= $c %>">
    <div class="navarrows">
     <a href="#threadlistbox">&uArr;</a>
     <a href="#t-<%= $c==1?(10>@$threads?scalar @$threads:10):$c-1 %>">&uarr;</a>
     <a href="#t-<%= (($c==10||$c==@$threads)?1:$c+1) %>">&darr;</a>
    </div>
    <p class="threadtitle">
     <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $id %>">
      <%= $title %></a>
     (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
    </p>

<%

    my $sth=$dbh->prepare('SELECT * FROM posts WHERE thread=? AND NUM = 1;') or
     die S_DBERR;
    $sth->execute($id) or die S_DBERR;
    show_post($sth->fetchrow_array());
    $sth=$dbh->prepare('SELECT * FROM posts WHERE thread=? AND num !=1 ORDER '.
     'BY num DESC LIMIT 9;') or die S_DBERR;
    $sth->execute($id) or die S_DBERR;
    my $posts=$sth->fetchall_arrayref();
    my $post;
    for $post (reverse @$posts){
     show_post(@$post);
    }
    reply_form($id,$postcount);

%>

   </div>

<%

   }
  }
 }

 sub full_thread_list(){
  my $thread;
  for $thread (@$threads){
   my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=@$thread;

%>

  <p>
   <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $id %>">
    <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
   </a>
  </p>

<%

  }
 }

 sub show_thread($){
  my($thread)=@_;
  my $sth=$dbh->prepare('SELECT * FROM threads WHERE id=? AND deleted=0;') or
   die S_DBERR;
  $sth->execute($thread) or die S_DBERR;
  my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=$sth->fetchrow_array();
  die S_NOTHR if $deleted or !$title;
  $sth=$dbh->prepare('SELECT * FROM posts WHERE thread=?;') or die S_DBERR;
  $sth->execute($thread) or die S_DBERR;
  my $posts=$sth->fetchall_arrayref();

%>

  <div class="<%= $permasaged?'permasaged':'' %>thread">
   <p class="threadtitle">
    <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
   </p>

<%

  my $post;
  for $post (@$posts){
   show_post(@$post);
  }
  reply_form($thread,$postcount);

%>

  </div>

<%

 }

 sub show_thread_posts($$){
  my($thread,$specs)=@_;
  my $sth=$dbh->prepare('SELECT * FROM threads WHERE id=? AND deleted=0;') or
   die S_DBERR;
  $sth->execute($thread) or die S_DBERR;
  my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=
   $sth->fetchrow_array();
  die S_NOTHR if $deleted or !$title;

%>

  <div class="<%= $permasaged?'permasaged':'' %>thread">
   <p class="threadtitle">
    <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
   </p>

<%

  my @specs=split(/,/,$specs);
  my @posts;
  my $spec;
  for $spec (@specs){
   if($spec=~/^[0-9]{1,4}$/ and $spec<=$postcount){
    push(@posts,$spec);
   }elsif($spec=~/^([0-9]{0,4})\-([0-9]{0,4})$/){
    if(!$1 and !$2){
     push(@posts,1..$postcount);
    }elsif($1 and !$2 and $1<$postcount){
     push(@posts,($1||1)..$postcount);
    }elsif($2 and !$1 and $2<1001){
     push(@posts,1..(($postcount<$2)?$postcount:$2));
    }elsif($1<$2 and $2<1001){
     push(@posts,($1||1)..(($postcount<$2)?$postcount:$2));
    }elsif($1>$2 and $1<1001){
     push(@posts,reverse(($2||1)..(($postcount<$1)?$postcount:$1)));
    }elsif($1==$2 and $1<=$postcount and $1){
     push(@posts,$1);
    }
   }elsif($spec=~/^l([0-9]{0,4})$/){
    my $start=1+$postcount-$1;
    $start=1 if $start<1;
    push(@posts,$start..$postcount);
   }elsif($spec=~/^r([0-9]{0,4})$/){
    push(@posts,map{int(rand($postcount)+1)}1..($1||1));
   }
  }
  @posts=(1..$postcount) unless @posts;
  die 'too many posts' if scalar(@posts)>2000;
  $sth=$dbh->prepare('SELECT * FROM posts WHERE thread=?;') or die S_DBERR;
  $sth->execute($thread) or die S_DBERR;
  my $all_posts=$sth->fetchall_arrayref();
  my $post;
  for $post (@posts){
   show_post(@{$$all_posts[$post-1]});
  }
  reply_form($thread,$postcount);

%>

  </div>

<%

 }

 sub show_post($$$$$$$$$$$){
  my($num,$thread,$time,$name,$trip,$link,$comment,$ip,$file,$filename,$deleted)=@_;
  if($deleted){

%>

  <div class="post">
   <p class="deleted"><%= S_DELETEDPOST %></p>
  </div>

<% }else{ %>

   <div class="post">
    <p class="postheader">
     <span class="postnum"><%= $num %></span>
     <%= S_NAME %>

<% if($link){ %>

     <a href="<%= $link %>">

<% } %>

      <span class="postername"><%= $name %></span>
      <span class="postertrip"><%= $trip %></span>

<% if($link){ %>

     </a>

<% } %>

     : <span class="posttime"><%= $time %></span>
     <%= S_ID %><span class="id"><%= $link=~/sage/?'Heaven':make_id($thread.$ip) %></span>
    </p>
    <div class="postbody">

<%

    if($file){ 
     my @fileparts=split /\./,$file;
     my $ext=pop @fileparts;
     my $file=join '.',@fileparts;

%>

     <div class="image">
      <a href="<%= expand_filename("src/$file.$ext") %>">

<% if($ext =~ /^(?:jpg|gif|png|svg)$/){ %>

       <img src="<%= expand_filename("thumb/$file.gif") %>" alt="<%= $filename %>" title="<%= $filename %>" />

<% } else { %>

       <span class="nothumb"><%= S_NOTHUMB %>:<br /><%= $filename %></span>

<% } %>

      </a>
     </div>

<%

    }

%>

     <div class="commenttext">
      <%= $comment %>
     </div>
    </div>
   </div>

<%

  }
 }

 sub reply_form($$){
  my($thread,$postcount)=@_;
  if($postcount>999){

%>

    <p class="threadclosed"><%= S_CLOSED %></p>
    <p class="threadnav">
     <a href="<%= $ENV{SCRIPT_NAME} %><%= $thread %>"><%= S_ENTIRE %></a>
     <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $thread %>/-100"><%= S_FIRST100 %></a>
     <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $thread %>/l50"><%= S_LAST50 %></a>
    </p>

<% }else{ %>

    <form class="postform" action="<%= $ENV{SCRIPT_NAME} %>" method="post"
      enctype="multipart/form-data">
     <p>
      <input type="hidden" name="task" value="post" />
      <input type="hidden" name="thread" value="<%= $thread %>" />
      <span style="display:none;">
       <label for="name-<%= $thread %>">Spam: </label>
       <input type="text" name="name" id="name-<%= $thread %>" />
       <label for="link-<%= $thread %>">Spam: </label>
       <input  type="text" name="link" id="link-<%= $thread %>" /><br />
      </span>
      <label for="field1-<%= $thread %>"><%= S_NAME %></label>
      <input type="text" name="field1" id="field1-<%= $thread %>" />
      <label for="field2-<%= $thread %>"><%= S_LINK %></label>
      <input type="text" name="field2" id="field2-<%= $thread %>" />
      <input type="submit" value="<%= S_REPLY %>" /><br />
      <label for="comment-<%= $thread %>"><%= S_COMMENT %></label><br />
      <textarea name="comment" rows="6" cols="60" id="comment-<%= $thread %>"></textarea><br />
      <label for="file-<%= $thread %>"><%= S_IMAGE %></label>
      <input type="file" name="file" id="file-<%= $thread %>" />
     </p>
     <p class="threadnav">
      <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $thread %>"><%= S_ENTIRE %></a>
      <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $thread %>/-100"><%= S_FIRST100 %></a>
      <a href="<%= $ENV{SCRIPT_NAME} %>/<%= $thread %>/l50"><%= S_LAST50 %></a>
     </p>
    </form>

<%

  }
 }

 sub get_threads(){
  my $sth=$dbh->prepare('SELECT * FROM threads WHERE deleted=0 ORDER BY '.
   'lasthit DESC;') or die S_DBERR;
  $sth->execute() or die S_DBERR;
  return $sth->fetchall_arrayref();
 }

 sub make_post($$$$;$$){
  my($thread,$name,$link,$comment,$title,$file)=@_;
  my($trip,$filename);
  die S_HAX unless $thread=~/^[0-9]*$/;
  $name=substr($name,0,128);
  $link=substr($link,0,512);
  $comment=substr($comment,0,8192);
  $title=substr($title,0,256);
  ($name,$trip)=process_tripcode($name,'!',SECRET,'utf8');
  $name=ANON_NAME if !$name and !$trip;
  #$link=clean_string(decode_string($link,'utf8'));
  $link=my_clean_string($link);
  $name=gethostbyaddr inet_aton($ip),AF_INET or $ip if $link=~/fusianasan/;
  $link="mailto:$link" if($link and $link!~/^$PerlHP::Utils::protocol_re:/);
  #$comment=~s/^(>>[0-9\-,]+)/ $1/gm;
  #$comment=do_wakabamark(undef,0,$comment);
  $comment=format_post(my_clean_string($comment),$thread);
  die S_NOTEXT unless $comment;
  die S_SPAM if spam_check($link."\n".$comment,SPAM_FILE);
  if($file){
   #$filename=clean_string(decode_string($file,'utf8'));
   $filename=my_clean_string($file);
   my $fh=upload('file');
   binmode($fh);
   my $buffer;
   my $size=-s $fh;
   die S_TOOBIG if $size>MAX_FILE_SIZE;
   my($ext,$height,$width)=analyze_image($fh);
   if(!$width){
    $ext='invalid';
    if($filename=~/\.([^\.])$/){
     $ext=$1;
    }
    if($ext=~/^(jpg|gif|png|svg)$/){
     $ext.='.invalid';
    }
   }
   seek($fh,0,0);
   my $sha=Digest::SHA->new(256);
   read $fh,$buffer,$size;
   $sha->add($buffer);
   $file=$sha->hexdigest;
   seek($fh,0,0);
   open OUTFILE,"+>src/${file}.${ext}" or die S_NOWRITE;
   binmode OUTFILE;
   print OUTFILE $buffer or die S_NOWRITE;
   close $fh;
   close OUTFILE;
   if($ext =~ /^(?:jpg|gif|png|svg)$/){
    my $tn_height=100;
    my $tn_width=int($width*100/$height);
    if($ext eq 'svg'){
     `svg2png -w $tn_width -h $tn_height src/${file}.${ext} -|convert -size ${tn_width}x${tn_height} -geometry ${tn_width}x${tn_height} - thumb/${file}.gif`;
     `convert -size ${tn_width}x${tn_height} -geometry ${tn_width}x${tn_height} src/${file}.${ext} thumb/${file}.gif` if $?;
    }else{
     `convert -size ${tn_width}x${tn_height} -geometry ${tn_width}x${tn_height} src/${file}.${ext} thumb/${file}.gif`;
    }
   }
   $file=$file.'.'.$ext;
  }
  my $sth;
  if($thread==0){
   #$title=clean_string(decode_string($title,'utf8'));
   $title=my_clean_string($title);
   die S_NOTITLE unless $title;
   $sth=$dbh->prepare('INSERT INTO threads VALUES(null,?,?,?,0,0);') or die
    S_DBERR;
   $sth->execute($title,time,0) or die S_DBERR;
   $sth=$dbh->prepare('SELECT id FROM threads WHERE id IS NULL;') or
    die S_DBERR;
   $sth->execute() or die S_DBERR;
   ($thread)=$sth->fetchrow_array();
  }
  $sth=$dbh->prepare('SELECT * FROM threads WHERE id=?;') or die S_DBERR;
  $sth->execute($thread) or die S_DBERR;
  my($thread,$title,$lasthit,$postcount,$permasaged,$deleted)=
   $sth->fetchrow_array();
  #my $tl="$ENV{SCRIPT_NAME}/$thread";
  #$comment=~s/(&gt;&gt;((?:[0-9\-]|&#44;)+))/<a href="$tl\/$2" rel="nofollow">$1<\/a>$3/g;
  ++$postcount;
  my $time=scalar(gmtime(time));
  $sth=$dbh->prepare('INSERT INTO posts VALUES(?,?,?,?,?,?,?,?,?,?,0);') or
   die S_DBERR;
  $sth->execute($postcount,$thread,$time,$name,$trip,$link,$comment,
   $ENV{REMOTE_ADDR},$file,$filename) or die S_DBERR.' '.$sth->errstr;
  $lasthit=time unless $link=~/sage/ or $permasaged;
  $sth=$dbh->prepare('UPDATE threads SET lasthit=?,postcount=? WHERE id=?;') or
   die S_DBERR;
  $sth->execute($lasthit,$postcount,$thread) or die S_DBERR;
  close_db();
  header('Status: 301 Go West');
  header("Location: $ENV{SCRIPT_NAME} ");
 }

 sub open_db(){
  $dbh=DBI->connect(SQL_DBI_SOURCE,SQL_USERNAME,SQL_PASSWORD,{AutoCommit=>1})
   or die S_SQLCONF;
  my $sth=$dbh->prepare('CREATE TABLE IF NOT EXISTS threads(id BIGINT UNSIGNED'.
   ' UNIQUE PRIMARY KEY AUTO_INCREMENT NOT NULL,title TEXT,lasthit INTEGER '.
   'UNSIGNED NOT NULL,postcount SMALLINT UNSIGNED,permasaged BOOL,deleted BOOL'.
   ',lastmod TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,'.
   'INDEX threadindex (id));') or die S_DBERR;
  $sth->execute() or die S_DBERR;
  $sth=$dbh->prepare('CREATE TABLE IF NOT EXISTS posts(num SMALLINT UNSIGNED '.
   'NOT NULL,thread BIGINT UNSIGNED NOT NULL REFERENCES threads(id),time TEXT,'.
   'name TEXT,trip TEXT,link TEXT,comment TEXT,ip TEXT,file TEXT,filename TEXT'.
   ',deleted BOOL,INDEX postindex (thread,num));') or die S_DBERR;
  $sth->execute() or die S_DBERR;
 }

 sub close_db(){
  $dbh->disconnect();
 }

 sub make_id($){
  my($text)=@_;
  return encode_base64(rc4(null_string(6),$text.SECRET),"");
 }

 sub expand_filename($){
  my ($filename)=@_;
  return $filename if($filename=~m!^/!);
  return $filename if($filename=~m!^\w+:!);

  my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
  return $self_path.$filename;
 }

sub my_clean_string($){
 my($str)=@_;
 $str=decode('utf8',$str) if $has_encode;
 $str=~s/&/&amp;/g;
 $str=~s/</&lt;/g;
 $str=~s/>/&gt;/g;
 $str=~s/"/&quot;/g;
 $str=~s/'/&#39;/g;
 $str=~s/[\x00-\x08\x0b\x0c\x0e-\x1f\x80-\x84]//g; # control chars
 $str=~s/[\x{d800}-\x{dfff}]//g; # surrogate code points
 $str=~s/[\x{202a}-\x{202e}]//g; # text direction
 $str=~s/[\x{fdd0}-\x{fdef}\x{fffe}\x{ffff}\x{1fffe}\x{1ffff}\x{2fffe}\x{2ffff}\x{3fffe}\x{3ffff}\x{4fffe}\x{4ffff}\x{5fffe}\x{5ffff}\x{6fffe}\x{6ffff}\x{7fffe}\x{7ffff}\x{8fffe}\x{8ffff}\x{9fffe}\x{9ffff}\x{afffe}\x{affff}\x{bfffe}\x{bffff}\x{cfffe}\x{cffff}\x{dfffe}\x{dffff}\x{efffe}\x{effff}\x{ffffe}\x{fffff}]//g; # non-characters
 $str=join('',map{$_<0x10fffe?$_:''}split(//,$str));
 return $str;
}

sub format_post($$){
 my $protocol_re=qr/(?:http|https|ftp|mailto|nntp)/;
 my($text,$thread)=@_;
 $text=~s/\r\n/\n/sg; # fix newlines
 $text=~s/\r/\n/sg; # fix newlines
 $text=~s{($protocol_re:[^\s<>"]*?)((?:\s|<|>|"|\.|\)|\]|!|\?|,|&#44;|&quot;)*(?:[\s<>"]|$))}{<a href="$1" rel="nofollow">${1}</a>$2}sg; # hyperlink urls
 $text=~s/&gt;&gt;([0-9,\-]+)/<a href="$ENV{SCRIPT_NAME}\/$thread\/$1">&gt;&gt;$1<\/a>/g; # >> links
 $text=~s/^(&gt;.*)$/<blockquote><p>$1<\/p><\/blockquote>/mg; # blockquotes
 $text=~s/^\x{3000}(.*)$/<p lang="ja">$1<\/p>/mg; # sjis art
 $text=~s/^    (.*)$/<code>$1<\/code>/mg; # code sections
 $text=~s/^spoiler:(.*)$/<div class="spoiler"><input type="button" class="spoilerbutton" value="spoiler" onclick="this.parentNode.getElementsByTagName('div')[0].style.display='block';this.style.display='none'" \/><div class="spoilertext">$1<\/div><\/div>/mg; # spoilers
 $text=~s/<\/p><\/blockquote>\n<blockquote><p>/\n/sg; # fixup multiline quotes
 $text=~s/<\/p>\n<p lang="ja">/\n/sg; # fixup multiline sjis art
 $text=~s/<\/code>\n<code>/\n/sg; # fixup multiline code sections
 $text=~s/<\/div><\/div>\n<div class="spoiler"><input type="button" class="spoilerbutton" value="spoiler" onclick="this.parentNode.getElementsByTagName('div')[0].style.display='block';this.style.display='none'" \/><div class="spoilertext">/\n/sg; # fixup multiline spoilers
 $text=~s/(<\/(?:blockquote|p)>)\n/$1/sg; # remove newlines after blockquotes
 $text=~s/\n(<blockquote)/$1/sg; # remove newlines before blockquotes
 $text=~s/\n/<br \/>/sg; # convert newlines to <br />
 return $text;
}

%>
