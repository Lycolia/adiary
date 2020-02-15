use strict;
#------------------------------------------------------------------------------
# 日本語全角→半角変換
#						(C)2010 nabe / nabe@abk.nu
#------------------------------------------------------------------------------
package Satsuki::Code::Jzen2han;
use utf8;
use Encode ();
our $VERSION = '1.00';
###############################################################################
# ■基本処理
###############################################################################
#------------------------------------------------------------------------------
# ●【コンストラクタ】
#------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $self  = {ROBJ => shift};
	return bless($self, $class);
}

###############################################################################
# ■メインルーチン
###############################################################################
#------------------------------------------------------------------------------
# ●変換処理
#------------------------------------------------------------------------------
sub utf8_zen2han {
	# 引数処理
	my $self = ($_[0] eq __PACKAGE__ || ref($_[0]) eq __PACKAGE__) && shift;
	my ($str, $alpha_only) = @_;
	if (ref($str) ne 'SCALAR') { my $s=$str; $str=\$s; }

	# main
	my $flag = utf8::is_utf8($$str);
	Encode::_utf8_on($$str);

	if ($alpha_only) {
		$$str =~ tr/０-９Ａ-Ｚａ-ｚ/ 0-9A-Za-z/;
	} else {
		$$str =~ tr/　！”＃＄％＆’（）＊＋，−．／０-９：；＜＝＞？＠Ａ-Ｚ［¥］＾＿｀ａ-ｚ｛｜｝/ -}/;
	}

	if (!$flag) { Encode::_utf8_off($$str); }
	return $$str;
}

#------------------------------------------------------------------------------
# ●半角カタカナを全角に
#------------------------------------------------------------------------------
my %hankana_map = (
'ｶﾞ'=>'ガ','ｷﾞ'=>'ギ','ｸﾞ'=>'グ','ｹﾞ'=>'ゲ','ｺﾞ'=>'ゴ',
'ｻﾞ'=>'ザ','ｼﾞ'=>'ジ','ｽﾞ'=>'ズ','ｾﾞ'=>'ゼ','ｿﾞ'=>'ゾ',
'ﾀﾞ'=>'ダ','ﾁﾞ'=>'ヂ','ﾂﾞ'=>'ヅ','ﾃﾞ'=>'デ','ﾄﾞ'=>'ド',
'ﾊﾞ'=>'バ','ﾋﾞ'=>'ビ','ﾌﾞ'=>'ブ','ﾍﾞ'=>'ベ','ﾎﾞ'=>'ボ',
'ﾊﾟ'=>'パ','ﾋﾟ'=>'ピ','ﾌﾟ'=>'プ','ﾍﾟ'=>'ペ','ﾎﾟ'=>'ポ',
'ｳﾞ'=>'ヴ');

sub utf8_hankana2zen {
	# 引数処理
	my $self = ($_[0] eq __PACKAGE__ || ref($_[0]) eq __PACKAGE__) && shift;
	my ($str) = @_;
	if (ref($str) ne 'SCALAR') { my $s=$str; $str=\$s; }

	# main
	my $flag = utf8::is_utf8($$str);
	Encode::_utf8_on($$str);

	$$str =~ s/(ｶﾞ|ｷﾞ|ｸﾞ|ｹﾞ|ｺﾞ|ｻﾞ|ｼﾞ|ｽﾞ|ｾﾞ|ｿﾞ|ﾀﾞ|ﾁﾞ|ﾂﾞ|ﾃﾞ|ﾄﾞ|ﾊﾞ|ﾋﾞ|ﾌﾞ|ﾍﾞ|ﾎﾞ|ﾊﾟ|ﾋﾟ|ﾌﾟ|ﾍﾟ|ﾎﾟ|ｳﾞ)/$hankana_map{$1}/g;
	$$str =~ tr/｡-ﾟ/。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜/;

	if (!$flag) { Encode::_utf8_off($$str); }
	return $$str;
}

1;
