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

 BEGIN {
  our $lang;
  our $c_lang;
  $lang=$c_lang unless $lang;
  my %langs=LANGS;
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
   header('Content-Type: text/vnd.wap.wml; charset=utf-8');
   header('Date: '.make_date(time(),'http'));
   header('Last-Modified: '.make_date($modified,'http'));

%>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
 <card id="bbs" title="<%= TITLE %>">

<% if($ENV{PATH_INFO}=~/\/subback\/?.*/){ %>

  <p>
   *: <a accesskey="*" href="<%= $ENV{SCRIPT_NAME} %>"><%= S_RETURN %></a>
  </p>
  <p>
<% full_thread_list() %>
  </p>

<% }elsif($ENV{PATH_INFO}=~/^\/+([0-9]+)\/+([lr0-9,\-]+)\/?.*/){ %>

  <p>
   *: <a accesskey="*" href="<%= $ENV{SCRIPT_NAME} %>"><%= S_RETURN %></a><br />
   0: <a accesskey="0" href="<%= $ENV{SCRIPT_NAME} %>/<%= $1 %>"><%= S_ENTIRE %></a><br />
   #: <a accesskey="#" href="#replyform"><%= S_REPLY %></a>
  </p>

<% show_thread_posts($1,$2) %>

<% }elsif($ENV{PATH_INFO}=~/^\/+([0-9]+)\/?.*/){ %>

  <p>
   *: <a accesskey="*" href="<%= $ENV{SCRIPT_NAME} %>"><%= S_RETURN %></a><br />
   #: <a accesskey="#" href="#replyform"><%= S_REPLY %></a>
  </p>

<% show_thread($1) %>

<% }else{ %>

  <p>
   #: <a accesskey="#" href="#threadform"><%= S_CREATETHR %></a>
  </p>
  <p>
<% main_page_thread_list() %>
  </p>
 </card>
 <card id="threadform" title="<%= TITLE %>  - <%= S_CREATETHR %>">
  <p>
   *: <a accesskey="*" href="#bbs"><%= S_RETURN %></a>
  </p>
  <p>
   <%= S_NAME %> <input type="text" name="field1" /><br />
   <%= S_LINK %> <input type="text" name="field2" /><br />
   <%= S_TITLE %> <input type="text" name="title" /><br />
   <%= S_COMMENT %> <input type="text" name="comment" /><br />
   <anchor>
    <go method="post" href="<%= $ENV{SCRIPT_NAME} %>">
     <postfield name="task" value="post" />
     <postfield name="field1" value="$(field1)" />
     <postfield name="field2" value="$(field2)" />
     <postfield name="title" value="$(title)" />
     <postfield name="comment" value="$(comment)" />
    </go>
    <%= S_CREATETHR %>
   </anchor>
  </p>

<% } %>

 </card>
</wml>

<%

  }
 }

 close_db();

 sub main_page_thread_list(){
  my $thread;
  my $i=1;
  for $thread (@$threads){
   my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=@$thread;

%>

  <p>
   <%= $i==10?0:$i %>:
   <a accesskey="<%= $i==10?0:$i %>" href="<%= $ENV{SCRIPT_NAME} %>/<%= $id %>">
    <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
   </a>
  </p>

<%

   ++$i;
   last if $i>10;
  }

%>

  <p>*: <a accesskey="*" href="<%= $ENV{SCRIPT_NAME} %>/subback/"><%= S_ALLTHR %></a></p>

<%

 }

 sub full_thread_list(){
  my $thread;
  my $i=1;
  for $thread (@$threads){
   my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=@$thread;

%>

  <p>
   <% if($i<11){ %><%= $i==10?0:$i %>:<% } %>
   <a
    <% if($i<11){ %> accesskey="<%= $i==10?0:$i %>" <% } %>
    href="<%= $ENV{SCRIPT_NAME} %>/<%= $id %>"
   >
    <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
   </a>
  </p>

<%

   ++$i;
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

  <p>
   <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)
  </p>

<%

  my $post;
  for $post (@$posts){
   show_post(@$post);
  }
  reply_form($thread,$postcount);
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

  <p>
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
 }

 sub show_post($$$$$$$$$$$){
  my($num,$thread,$time,$name,$trip,$link,$comment,$ip,$file,$filename,$deleted)=@_;
  my $ext;
  my @fileparts=split /\./,$file if $file;
  my $ext=pop @fileparts if $file;
  $file=join '.',@fileparts if $ext;
  if($deleted){

%>

  <p>
   <p><%= S_DELETEDPOST %></p>
  </p>

<% }else{ %>

   <p>
    <p><small>
     <strong><%= $num %></strong>
     <%= S_NAME %>

<% if($link){ %>

     <a href="<%= $link %>">

<% } %>

      <%= $name %>
      <i><%= $trip %></i>

<% if($link){ %>

     </a>

<% } %>

     : <%= $time %>
     <%= S_ID %><%= $link=~/sage/?'Heaven':make_id($thread.$ip) %>

<% if($file and $ext=~/^(?:jpg|gif|png|svg)$/){ %>

     <a href="<%= expand_filename("gcd.pl?file=$file.$ext") %>"><%= S_DLIMAGE %>: <%= $filename %></a>

<% }elsif($file){ %>

     <a href="<%= expand_filename("src/$file.$ext") %>"><%= $filename %></a>

<% } %>

    </small></p>
    <p>

<% if($file){ %>

     <p>
      <a href="<%= expand_filename("src/$file.$ext") %>">

<% if($ext =~ /^(?:jpg|gif|png|svg)$/){ %>

       <img src="<%= expand_filename("thumb/$file.gif") %>" alt="<%= $filename %>" title="<%= $filename %>" />

<% } else { %>

       <%= S_NOTHUMB %>: <%= $filename %>

<% } %>

      </a>
     </p>

<% } %>

     <p>
      <%= $comment %>
     </p>
    </p>
   </p>

<%

  }
 }

 sub reply_form($$){
  my($thread,$postcount)=@_;

%>

 </card>
 <card id="replyform" title="<%= TITLE %> - <%= S_REPLY %>">
  <p>
   *: <a accesskey="*" href="#bbs"><%= S_RETURN %></a>
  </p>
  <p>

<%

  if($postcount>999){

%>

   <%= S_CLOSED %>

<% }else{ %>

   <%= S_NAME %> <input type="text" name="field1" /><br />
   <%= S_LINK %> <input type="text" name="field2" /><br />
   <%= S_COMMENT %> <input type="text" name="comment" /><br />
   <anchor>
    <go method="post" href="<%= $ENV{SCRIPT_NAME} %>">
     <postfield name="task" value="post" />
     <postfield name="thread" value="<%= $thread %>" />
     <postfield name="field1" value="$(field1)" />
     <postfield name="field2" value="$(field2)" />
     <postfield name="title" value="$(title)" />
     <postfield name="comment" value="$(comment)" />
    </go>
    <%= S_REPLY %>
   </anchor>

<%

  }

%>

  </p>

<%

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
  $comment=format_post(my_clean_string(comment),$thread);
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
    if($ext=~/^(jpg|gif|png)$/){
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
 $text=~s{($protocol_re:[^\s<>"]*?)((?:\s|<|>|"|\.|\)|\]|!|\?|,|&#44;|&quot;)*(?:[\s<>"]|$))}{<a href="$1" rel="nofollow">$1\</a>}sg; # hyperlink urls
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

