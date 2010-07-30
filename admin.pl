#!/usr/bin/env perl

use strict;
use PerlHP;

<%

 use DBI;
 use PerlHP::Utils;

 use lib '.';
 BEGIN { require 'config.pl'; }

 my $dbh;
 open_db();
 my $threads=get_threads();

 BEGIN {
  our $lang;
  our $c_lang;
  $lang=$c_lang if !$lang;
  my %langs=LANGS;
  $lang=LANG_DEFAULT if(!$langs{$lang});
  require "strings_$lang.pl";
 }

 our $task;
 our $admin_pass;

 if($admin_pass eq ADMIN_PASS or $admin_pass eq crypt(ADMIN_PASS,substr(crypt(
  SECRET,time()>>17),-2)) or $admin_pass eq crypt(ADMIN_PASS,substr(crypt(
  SECRET,(time()>>17)-1),-2))){
  if($task eq 'reset'){
   delete_all();
  }elsif($task eq 'delete_ip'){
   our $ip;
   delete_ip($ip);
  }elsif($task eq 'ban'){
   our $ip;
   ban($ip);
  }elsif($task eq 'delete_file'){
   our $file;
   delete_file($file);
  }else{
   our $thread;
   if($task eq 'permasage'){
    permasage($thread);
   }elsif($task eq 'unpermasage'){
    unpermasage($thread);
   }elsif($task eq 'undelete_thread'){
    undelete_thread($thread);
   }else{
    my $threads=get_threads();
    if($task eq 'delete'){
     our $post;
     delete_posts($thread,$post);
    }elsif($task eq 'undelete'){
     our $post;
     undelete_post($thread,$post);
    }else{
     $task='adminpanel';
    }
   }
  }
  $admin_pass=crypt(ADMIN_PASS,substr(crypt(SECRET,time()>>17),-2));
  cookie('admin_pass',$admin_pass,(time()>>17)+1<<17);
 }else{
  cookie('admin_pass','',time()-604800);
  $task='loginform';
 }

 make_redirect() if $ENV{REQUEST_METHOD} eq 'POST';

 header('Content-Type: '.($ENV{HTTP_ACCEPT}=~/application\/xhtml\+xml/?
  'application/xhtml+xml':'text/html').'; charset=utf-8');

 if($ENV{REQUEST_METHOD} ne 'POST'){

%>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="<%= S_LANG %>" xml:lang="<%= S_LANG %>">
 <head>
  <title><%= sprintf(S_ADMIN,TITLE) %></title>
  <link rel="stylesheet" type="text/css" href="<%= STYLESHEET %>" />
  <link rel="shortcut icon" type="image/x-ico" href="<%= FAVICON %>" />
 </head>
 <body>

<% if($task eq 'loginform'){ %>

  <form action="<%= $ENV{SCRIPT_NAME} %>" method="post" id="loginform">
   <p>
    <input type="hidden" name="task" value="adminpanel" />
    <label for="adminpass"><%= S_PASSWORD %></label>
    <input type="password" name="admin_pass" id="adminpass" />
    <input type="submit" value="<%= S_LOGIN %>" />
   </p>
  </form>

<% }elsif($task eq 'adminpanel'){ %>

  <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
   <p>
    <input type="hidden" name="admin_pass" value="<%= $admin_pass %>" />
    <input type="hidden" name="task" value="delete_ip" />
    <label for="deleteip"><%= S_DELBYIP %></label>
    <input type="text" name="ip" id="deleteip" />
    <input type="submit" value="<%= S_DELETE %>" />
   </p>
  </form>
  <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
   <p>
    <input type="hidden" name="admin_pass" value="<%= $admin_pass %>" />
    <input type="hidden" name="task" value="ban" />
    <label for="banip"><%= S_BANLABEL %></label>
    <input type="text" name="ip" id="banip" />
    <input type="submit" value="<%= S_BAN %>" />
   </p>
  </form>
  <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
   <p>
    <input type="hidden" name="admin_pass" value="<%= $admin_pass %>" />
    <input type="hidden" name="task" value="reset" />
    <input type="submit" value="<%= S_RESET %>" />
   </p>
  </form>
  <div id="adminpanelthreads">

<% admin_panel_threads() %>

  </div>

<% } %>

  <p class="footer">
   -
    <%= sprintf(S_POWERED,'<a href="http://wakaba.c3.cx/perlhp/">PerlHP</a>',
     '<a href="http://www.mysql.com/">MySQL</a>') %>
   -
  </p>
 </body>
</html>

<%

 }
 close_db();

 sub admin_panel_threads(){
  my $thread;
  for $thread (@$threads){
   my($id,$title,$lasthit,$postcount,$permasaged,$deleted)=@$thread;

%>

   <div class="<%= $permasaged?'permasaged':'' %>thread">
    <%= $title %> (<%= $postcount %><%= $permasaged?', '.S_PERMASAGED:'' %>)

<% if($deleted){ %>

       <strong style="color:red"><%= S_DELETED %></strong>

<% } %>

    <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
     <p>
      <input type="hidden" name="admin_pass" value="<%= $admin_pass %>" />
      <input type="hidden" name="thread" value="<%= $id %>" />
      <input type="hidden" name="task" value="<% if($permasaged){ %>un<% } %>permasage" />
      <input type="submit" value="<%= $permasaged?S_UNPERMASAGE:S_PERMASAGE %>" />
     </p>
    </form>

    <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
     <p>
      <input type="hidden" name="admin_pass" value="<%= $admin_pass %>" />
      <input type="hidden" name="thread" value="<%= $id %>" />
      <input type="hidden" name="task" value="<%= $deleted?'undelete_thread':'delete' %>" />
      <input type="submit" value="<%= $deleted?S_UNDELETE:S_DELETE %>" />
     </p>
    </form>
    <div class="posts">

<%

   my $sth=$dbh->prepare('SELECT * FROM posts WHERE thread=? ORDER BY num;') or
    die S_DBERR;
   $sth->execute($id) or die S_DBERR;
   my $posts=$sth->fetchall_arrayref();
   my $post;
   for $post (@$posts){
    admin_panel_post(@$post);
   }

%>

    </div>
   </div>

<%

  }
 }

 sub admin_panel_post($$$$$$$$$$$){
  my($num,$thread,$time,$name,$trip,$link,$comment,$ip,$file,$filename,$deleted)=@_;

%>
     <div class="post">
      <div class="postheader">
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
       IP:<span class="id"><%= $ip %></span>

<% if($deleted){ %>

       <strong style="color:red"><%= S_DELETED %></strong>

<% } %>

       <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
        <p>
         <input type="hidden" name="admin_pass" value="<%= $admin_pass %>" />
         <input type="hidden" name="thread" value="<%= $thread %>" />
         <input type="hidden" name="post" value="<%= $num %>" />
         <input type="hidden" name="task" value="<% if($deleted){ %>un<% } %>delete" />
         <input type="submit" value="<%= $deleted?S_UNDELETE:S_DELETE %>" />
        </p>
       </form>

<% if($file){ %>
       <form action="<%= $ENV{SCRIPT_NAME} %>" method="post">
        <p>
         <input type="hidden"  name="admin_pass" value="<%= $admin_pass %>" />
         <input type="hidden" name="file" value="<%= $file %>" />
         <input type="submit" value="<%= S_DELETEFILE %>" />
        </p>
       </form>

<% } %>

      </div>
      <div class="postbody">

<%

    if($file){ 
     my @fileparts=split /\./,$file;
     my $ext=pop @fileparts;
     my $file=join '.',@fileparts;

%>

       <div class="image">
        <a href="src/<%= $file %>.<%= $ext %>">

<% if($ext =~ /^(?:jpg|gif|png|svg)$/){ %>

         <img src="thumb/<%= $file %>.gif" alt="<%= $filename %>" title="<%= $filename %>" />

<% } else { %>

         <div class="nothumb">No Thumbnail</div>

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

 sub permasage($){
  my($thread)=@_;
  my $sth=$dbh->prepare('UPDATE threads SET permasaged=1 WHERE id=?;') or die
   S_DBERR;
  $sth->execute($thread) or die S_DBERR;
 }

 sub unpermasage($){
  my($thread)=@_;
  my $sth=$dbh->prepare('UPDATE threads SET permasaged=0 WHERE id=?;') or die
   S_DBERR;
  $sth->execute($thread) or die S_DBERR;
 }

 sub delete_posts($;$){
  my($thread,$post)=@_;
  my $sth;
  if($post){
   $sth=$dbh->prepare('UPDATE posts SET deleted=1 WHERE thread=? AND num=?;') or
    die S_DBERR;
   $sth->execute($thread,$post) or die S_DBERR;
  }elsif(scalar(@$threads)==1){
   delete_all();
  }else{
   $sth=$dbh->prepare('UPDATE threads SET deleted=1 WHERE id=?;') or die
    S_DBERR;
   $sth->execute($thread) or die S_DBERR;
  }
 }

 sub undelete_post($$){
  my($thread,$post)=@_;
  my $sth=$dbh->prepare('UPDATE posts SET deleted=0 WHERE thread=? AND num=?;') or
   die S_DBERR;
  $sth->execute($thread,$post) or die S_DBERR;
 }

 sub undelete_thread($){
  my($thread)=@_;
  my $sth=$dbh->prepare('UPDATE threads SET deleted=0 WHERE id=?;') or die
   S_DBERR;
  $sth->execute($thread) or die S_DBERR;
 }

 sub delete_all(){
  my $sth=$dbh->prepare('DROP TABLE threads,posts;') or die S_DBERR;
  $sth->execute() or die S_DBERR;
 }

 sub delete_ip($){
  my($ip)=@_;
  my $sth=$dbh->prepare('UPDATE posts SET deleted=1 WHERE ip LIKE ?;') or die
   S_DBERR;
  $sth->execute($ip) or die S_DBERR;
 }

 sub delete_file($){
  my($file)=@_;
  for('res','thumb'){
   open(HTACCESS,'>>res/.htaccess');
   print HTACCESS "<Files $file>\n",
    "Deny from All\n",
    "</Files>";
  }
 }

 sub ban($){
  my($ip)=@_;
  open(HTACCESS,'>>.htaccess');
  print HTACCESS "Deny from $ip\n";
 }

 sub make_redirect(){
  header('Status: 301 Go West');
  header("Location: $ENV{SCRIPT_NAME}");
 }

 sub get_threads(){
  my $sth=$dbh->prepare('SELECT * FROM threads ORDER BY lasthit DESC;') or die
   S_DBERR;
  $sth->execute() or die S_DBERR;
  return $sth->fetchall_arrayref();
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
   'name TEXT, trip TEXT, link TEXT,comment TEXT,ip TEXT,deleted BOOL,INDEX '.
   'postindex (thread,id));') or die
   S_DBERR;
  $sth->execute() or die S_DBERR;
 }

 sub close_db(){
  $dbh->disconnect();
 }

%>
