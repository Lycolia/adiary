use strict;
#------------------------------------------------------------------------------
# 更新されたライブラリの自動リロード
#						(C)2013-2017 nabe@abk
#------------------------------------------------------------------------------
package Satsuki::AutoReload;
our $VERSION = '1.10';
#------------------------------------------------------------------------------
my $Satsuki_pkg = 'Satsuki';
my %Libtime;
my @Libs;
#------------------------------------------------------------------------------
my $mypkg = __PACKAGE__ . '.pm';
$mypkg =~ s|::|/|g;
###############################################################################
# ●ライブラリの情報保存
###############################################################################
sub save_lib {
	if ($ENV{SatsukiReloadStop}) { return; }
	while (my ($pkg, $file) = each(%INC)) {
		if (index($pkg, $Satsuki_pkg) != 0) { next; }
		if ($pkg eq $mypkg)        { next; }
		if (exists $Libtime{$pkg}) { next; }
		$Libtime{$pkg} = (stat($file)) [9];
		push(@Libs, $pkg);
	}
}

###############################################################################
# ●更新されたモジュールをアンロードする
###############################################################################
sub check_lib {
	my $flag = shift || $Satsuki::Base::RELOAD;
	if (!$flag) {
		if ($ENV{SatsukiReloadStop}) { return; }
		foreach(@Libs) {
			if ($Libtime{$_} == (stat($INC{$_}))[9]) { next; }
			$flag=1;
			last;
		}
		if (!$flag) { return 0; }
	}

	# 更新されたものがあれば、ロード済パッケージをすべてアンロード
	foreach(@Libs) {
		delete $INC{$_};
		if ($_ =~ /_\d+\.pm$/i) { next; }	# _2.pm _3.pm 等は無視
		# 名前空間からすべて除去
		&unload($_);
	}
	undef %Libtime;
	undef @Libs;

	# 自分自身をリロード（unloadは危険なのでしない）
	delete $INC{$mypkg};
	require $mypkg;

	return 1;
}

#------------------------------------------------------------------------------
# ●指定されたパッケージをアンロードする
#------------------------------------------------------------------------------
sub unload {
	no strict 'refs';

	my $pkg = shift;
	$pkg =~ s/\.pm$//;
	$pkg =~ s[/][::]g;
	my $names = \%{ $pkg . '::' };
	# パッケージの名前空間からすべて除去
	foreach(keys(%$names)) {
		substr($_,-2) eq '::' && next;
		undef $names->{$_};		# 全型の変数開放

		# 以下を実行するとグローバル変数の参照に不具合が出る
		# delete $names->{$_};
	}
}

1;
