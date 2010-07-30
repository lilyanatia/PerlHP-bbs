#!/usr/bin/perl

use PerlHP;
<%
 our $file;
 die "invalid filename" unless $file =~ /^([a-z0-9]+)\.(jpg|gif|png)$/;
 $name = $1;
 $type = "image/$2";
 $type = 'image/jpeg' if $type eq 'image/jpg';
 die "file does not exist" if ! -e "src/$file";
 header("Content-Type: text/x-pcs-gcd");
%>
Content-Type: image/png
Content-ID: screensaver
Content-Name: <%= $name %>
Content-Version: 1.0
Content-Vendor: None
Content-URL: http://<%= $ENV{HTTP_HOST} %><%=
 $ENV{SERVER_PORT}==80?'':":$ENV{SERVER_PORT}" %><%=
 expand_filename('resize.pl')."?img=$file" %>
Content-Size: <%= 0+`convert src/$file -resize 240x320 png:-|wc -c` %>
<%
 sub expand_filename($){
  my ($filename)=@_;
  return $filename if($filename=~m!^/!);
  return $filename if($filename=~m!^\w+:!);
  my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
  return $self_path.$filename;
 }
*>
