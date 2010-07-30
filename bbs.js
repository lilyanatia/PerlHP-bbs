function init(){
 var forms = document.body.getElementsByTagName('form');
 for(var i = 0; i < forms.length; ++i){
  var preview_container = document.createElement('div');
  var preview = document.createElement('div');
  var post = document.createElement('div');
  var preview_comment = document.createElement('div');
  preview_container.className = 'preview';
  preview_container.style.display = 'none';
  preview.className = 'post';
  post.className = 'postbody';
  preview_comment.className = 'commenttext';
  post.appendChild(preview_comment);
  preview.appendChild(post);
  preview_container.appendChild(preview);
  forms[i].appendChild(preview_container);
  preview_comment = forms[i].lastChild.lastChild.lastChild.lastChild;
  var textarea = forms[i].getElementsByTagName('textarea')[0];
  textarea.onchange = textarea.onkeyup = function(){
   var comment = this.value;
   var thread = this.parentNode.parentNode.thread.value;
   var script_name = this.parentNode.parentNode.action;
   this.parentNode.parentNode.lastChild.style.display = comment ? 'block' : 'none';
   var commenttext = document.createElement('div');
   comment = format_comment(clean_string(comment), thread, script_name);
   this.parentNode.parentNode.lastChild.lastChild.lastChild.lastChild.innerHTML = comment;
   return true;
  }
 }

 function clean_string(str){
  str = str.replace(/&/g, '&amp;');
  str = str.replace(/</g, '&lt;');
  str = str.replace(/>/g, '&gt;');
  str = str.replace(/"/g, '&quot;');
  str = str.replace(/'/g, '&#39;');
  str = str.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x80-\x84]/g,'');
  str = str.replace(/[\ud800-\udfff]/g,'');
  str = str.replace(/[\u202a-\u202e]/g,'');
  str = str.replace(/[\ufdd0-\ufdef\ufffe\uffff]/g,'');
  return str;
 }

 function format_comment(text, thread, script_name){
  text = text.replace(/\r\n/g, '\n');
  text = text.replace(/\r/g, '\n');
  text = text.replace(/((http|https|ftp|mailto|nntp):[^\s<>"]*?)((\s|<|>|"|\.|\)|\]|!|\?|,|&#44;|&quot;)*([\s<>"]|$))/g, '<a href="$1" rel="nofollow">$1</a>$3');
  text = text.replace(/&gt;&gt;([0-9,\-]+)/g, '<a href="' + script_name + '/' + thread + '/$1">&gt;&gt;$1</a>');
  text = text.replace(/^(&gt;.*)$/mg, '<blockquote><p>$1</p></blockquote>');
  text = text.replace(/^\u3000(.*)$/mg, '<p lang="ja">$1</p>');
  text = text.replace(/^    (.*)$/mg, '<code>$1</code>');
  text = text.replace(/^spoiler:(.*)$/mg, '<div class="spoiler"><input type="button" class="spoilerbutton" value="spoiler" onclick="this.parentNode.getElementsByTagName(\'div\')[0].style.display=\'block\';this.style.display=\'none\'" \/><div class="spoilertext">$1<\/div><\/div>');
  text = text.replace(/<\/p><\/blockquote>\n<blockquote><p>/g, '\n');
  text = text.replace(/<\/p>\n<p lang="ja">/g, '\n');
  text = text.replace(/<\/code>\n<code>/g, '\n');
  text = text.replace(/<\/div><\/div>\n<div class="spoiler"><input type="button" class="spoilerbutton" value="spoiler" onclick="this.parentNode.getElementsByTagName('div')[0].style.display='block';this.style.display='none'" \/><div class="spoilertext">/g, '\n');
  text = text.replace(/(<\/(?:blockquote|p)>)\n/g, '$1');
  text = text.replace(/\n(<blockquote)/g, '$1');
  text = text.replace(/\n/g, '<br />');
  return text;
 }
}
