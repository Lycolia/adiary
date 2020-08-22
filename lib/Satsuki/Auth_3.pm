use strict;
#-------------------------------------------------------------------------------
# Split from Satsuki::Auth.pm for AUTOLOAD.
#-------------------------------------------------------------------------------
use Satsuki::Auth ();
use Satsuki::Auth_2 ();
package Satsuki::Auth;
###############################################################################
# ■ユーザーの管理
###############################################################################
#-------------------------------------------------------------------------------
# ●ユーザーの追加
#-------------------------------------------------------------------------------
sub user_add {
	my ($self, $form) = @_;
	my $ROBJ = $self->{ROBJ};
	my $DB   = $self->{DB};
	if (! $self->{isadmin}) {
		return { ret=>1, msg => $ROBJ->translate('Operation not permitted') };
	}

	$ROBJ->clear_form_err();

	# データチェック
	$form->{new_user} = 1;
	my $insert = $self->check_user_data( $form );

	# 追加チェック（上と順番を入れ替えないこと）
	my $id = $form->{id};
	my $user = $self->get_userinfo($id);
	if ($user && %$user) { $ROBJ->form_err('id', "ID '%s' already exists", $id); }
	if ($form->{pass} eq '' && $form->{crypted_pass} eq '') {
		$ROBJ->form_err('pass', 'Password is empty');
	}

	# エラー終了
	my $errs = $ROBJ->form_err();
	if (!$insert || $errs) {
		return { ret=>10, errs => $errs };
	}

	# ユーザーデータの追加
	$insert->{login_c} = 0;
	$insert->{fail_c}  = 0;
	my $r = $DB->insert( $self->{table}, $insert );
	if ($r) {
		$self->log_save($id, 'regist');
		return { ret => 0 };
	}
	return { ret => -1, msg => 'Internal Error' };
}

#-------------------------------------------------------------------------------
# ●削除処理
#-------------------------------------------------------------------------------
sub user_delete {
	my ($self, $del_ary) = @_;
	my $ROBJ = $self->{ROBJ};
	if (!ref($del_ary) && $del_ary ne '') { $del_ary = [ $del_ary ]; }

	if (! $self->{isadmin}) {
		return { ret=>1, msg => $ROBJ->translate('Operation not permitted') };
	}
	if (ref($del_ary) ne 'ARRAY' || !@$del_ary) {
		return { ret=>10, msg => $ROBJ->translate('No assignment delete user') };
	}

	my $DB    = $self->{DB};
	my $table = $self->{table};

	$DB->begin();
	$DB->delete_match($table.'_sid', 'id', $del_ary);
	my $r1 = $DB->delete_match($table       , 'id', $del_ary);
	my $r2 = $DB->commit();

	if ($r1 != $#$del_ary+1 || $r2) {
		$DB->rollback();
		return { ret=>-1, msg => "DB delete error: $r1 / " . ($#$del_ary+1) };
	}
	foreach(@$del_ary) {
		$self->log_save($_, 'delete');
	}
	return { ret => 0 };
}

#-------------------------------------------------------------------------------
# ●ユーザーの編集
#-------------------------------------------------------------------------------
sub user_edit {
	my ($self, $form) = @_;
	my $ROBJ = $self->{ROBJ};
	if (! $self->{isadmin}) {
		return { ret=>1, msg => $ROBJ->translate('Operation not permitted') };
	}

	return $self->update_user_data($form);
}

#-------------------------------------------------------------------------------
# ●ランダムなUID生成（emailログイン運用時）
#-------------------------------------------------------------------------------
sub generate_uid {
	my ($self, $str) = @_;
	my $ROBJ = $self->{ROBJ};
	my $DB = $self->{DB};

	my $id;
	foreach(0..99) {
		my $x = $ROBJ->crypt_by_rand_nosalt($str);
		my $h = $DB->select_match_limit1( $self->{table}, 'id', $x );
		if (!$h) { $id=$x; last; }
	}
	return $id;
}

###############################################################################
# ■ユーザー本人による変更
###############################################################################
#-------------------------------------------------------------------------------
# ●ユーザー名の変更（ユーザー本人）
#-------------------------------------------------------------------------------
sub change_user_info {
	my ($self, $form) = @_;
	my $ROBJ = $self->{ROBJ};
	if (! $self->{ok}) { $ROBJ->message('No login');                   return 1; }
	if ($self->{auto}) { $ROBJ->message("Can't execute with 'root*'"); return 1; }

	my @scols = qw(pass pass2);
	my @ncols = qw(name);
	{
		# カラム拡張
		my $extcol = $self->{extcol};
		foreach(@$extcol) {
			if ($_->{_secure}<0) { next; }
			if ($_->{_secure}) {
				push(@scols, $_->{name});
				next;
			}
			push(@ncols, $_->{name});
		}
	}

	my $id = $self->{id};
	my %h = (id => $id);
	my $secure = 0;
	if ($form->{now_pass} ne '') {
		if (! $self->check_pass_by_id($id, $form->{now_pass})) {
			$ROBJ->message('Incorrect password'); return 1;
		}
		# セキュアなカラムデータコピー
		foreach(@scols) {
			if (!exists $form->{$_}) { next; }
			$h{$_} = $form->{$_};
		}
	}
	# その他のカラムのコピー
	foreach(@ncols) {
		if (!exists $form->{$_}) { next; }
		$h{$_} = $form->{$_};
	}

	return $self->update_user_data( \%h );
}

#-------------------------------------------------------------------------------
# ●セキュアな変更
#-------------------------------------------------------------------------------
sub change_pass {
	my ($self, $form) = @_;
	my $ROBJ = $self->{ROBJ};
	if (! $self->{ok})       { $ROBJ->message('No login');                   return 1; }
	if ($self->{auto})       { $ROBJ->message("Can't execute with 'root*'"); return 1; }
	if ($form->{pass} eq '') { $ROBJ->message('New password is empty');      return 1; }

	my $id = $self->{id};
	if (! $self->check_pass_by_id($id, $form->{now_pass})) {
		$ROBJ->message('Incorrect password'); return 1;
	}

	return $self->update_user_data( {
		id    => $id,
		pass  => $form->{pass},
		pass2 => $form->{pass2}
	} );
}

###############################################################################
# ■スケルトンルーチン
###############################################################################
#-------------------------------------------------------------------------------
# ●全ユーザー情報のロード
#-------------------------------------------------------------------------------
sub load_userlist {
	my ($self, $sort) = @_;
	if (!$self->{isadmin}) { return []; }
	my $DB = $self->{DB};

	my $cols = [qw(pkey id name email login_c login_tm fail_c fail_tm disable isadmin) ];
	my $ucols = $self->load_extcols();
	push(@$cols, @$ucols);

	my $list = $DB->select($self->{table}, {
		cols =>$cols, 
		sort =>$sort || 'id'
	});
	return $list;
}

#------------------------------------------------------------------------------
# ●ユーザー情報のロード（パスワード以外）
#------------------------------------------------------------------------------
sub load_user_info {
	my $self = shift;
	my $id   = $self->{isadmin} ? shift : $self->{id};
	if (!$self->{ok}) { return; }

	my $DB = $self->{DB};
	my $h  = $DB->select_match_limit1( $self->{table}, 'id', $id );
	if (!$h) { return; }

	delete($h->{pass});
	return $h;
}

#------------------------------------------------------------------------------
# ●ログのロード
#------------------------------------------------------------------------------
sub load_logs {
	my $self  = shift;
	my $id    = shift;
	my $limit = shift || 100;
	my $DB    = $self->{DB};
	my $table = $self->{table} . '_log';

	my @arg = ('*sort', '-tm', '*limit', $limit);
	if ($id ne '') {
		unshift(@arg, 'id', $id);
	}
	return $DB->select_match($table, @arg);
}

###############################################################################
# ■サブルーチン
###############################################################################
#------------------------------------------------------------------------------
# ●ユーザーデータの整合性確認
#------------------------------------------------------------------------------
sub check_user_data {
	my ($self, $user) = @_;
	my $ROBJ = $self->{ROBJ};
	my $DB   = $self->{DB};

	$ROBJ->clear_form_err();

	# 整形済ユーザーデータ
	if (! ref $user eq 'HASH') {
		$ROBJ->form_err('', 'Internal Error(%s)', 'in check_user_data()');
		return undef;
	}

	# update用データ
	my %update;

	# IDの確認
	my $id = $user->{id};
	$id =~ s/[\r\n\0]//g;
	$ROBJ->trim($id);
	$user->{id} = $id;
	if ($id eq '') {
		$ROBJ->form_err('id', 'ID is empty');
	} else {
		if ($self->{uid_lower_rule}) {
			   if ($id =~ /\W/)     { $ROBJ->form_err('id',"ID's character allowed \"%s\" only", "0-9, a-z" . ($self->{uid_underscore} ? ', _':'')); }
			elsif ($id =~ /[A-Z]/)  { $ROBJ->form_err('id',"Don't use upper case in ID"); }
			elsif ($id =~ /^[\d_]/) { $ROBJ->form_err('id','ID first character must be lower case between "a" to "z"'); }
		} else {
			if ($id =~ /\W/) { $ROBJ->form_err('id',"ID's character allowed \"%s\" only", "0-9, A-Z, a-z" . ($self->{uid_underscore} ? ', _':'')); }
		}
		if (!$self->{uid_underscore} && $id =~ /_/) {
			if ($id =~ /^[\d_]/) { $ROBJ->form_err('id',"Don't use `_' in ID"); }
		}
		if ($id =~ /[\"\'<> ]/) {
			$ROBJ->form_err('id','ID not allow ", \', <, >, space character');
		}
		if (length($id) > $self->{uid_max_length}) {
			$ROBJ->form_err('id',"Too long ID (max %d)", $self->{uid_max_length});
		}
	}

	# ユーザー名の確認
	if (exists($user->{name})) {
		my $name = $user->{name};
		$ROBJ->trim($name);
		$name =~ s/[\r\n\0]//g;

		if ($name eq '') { $ROBJ->form_err('name','Name is empty'); }
		if ($self->{name_notag} && $name =~ /[\"\'<>]/) {
			$ROBJ->form_err('name','Name not allow ", \', <, > charcteor');
		}
		if (length($name) > $self->{name_max_length}) {
			$ROBJ->form_err('name',"Too long name (max %d)", $self->{name_max_length});
		}
		$update{name} = $name;
	}

	# パスワードの確認
	my $pass = $user->{pass};
	if ($pass ne '') {	# パスワードを変更する
		if ($self->{disallow_num_pass} && $pass =~ /^\d+$/) {
			$ROBJ->form_err('pass', "Not allow password is number only");
		}
		if (length($pass) < $self->{pass_min}) {
			$ROBJ->form_err('pass',"Too short password (min %d)", $self->{pass_min});
		} elsif (defined $user->{pass2} && $pass ne $user->{pass2}) {
			$ROBJ->form_err('pass2',"Mismatch password and retype password");
		} else {
			$pass = $ROBJ->crypt_by_rand($pass);
			$update{pass} = $pass;
		}
	}
	if ($user->{crypted_pass}) { $update{pass}=$user->{crypted_pass}; }
	if ($user->{disable_pass}) { $update{pass}='*'; }

	# エラー処理
	if ($ROBJ->form_err()) { return undef; }	# エラーがあった

	# ユーザーデータ生成
	if ($user->{new_user}) {
		$update{id}    = $id;
		$update{isadmin} = 0;
		$update{disable} = 0;
	}
	if (exists $user->{isadmin}) { $update{isadmin} = $user->{isadmin} ? 1 : 0; }
	if (exists $user->{disable}) { $update{disable} = $user->{disable} ? 1 : 0; }

	# ユーザ拡張カラム + email
	my @ary = @{ $self->{extcol} };
	push(@ary, {
		name	=> 'email',
		type	=> 'text',
		index	=> 1,
		unique	=> 1,
		_notag	=> 1,
		_nocrlf	=> 1
	});
	foreach(@ary) {
		my $k = $_->{name};
		$ROBJ->trim($k);
		if ($_->{type} eq 'int') {
			if ($user->{new_user})  { $update{$k} = 0; }
			if (exists $user->{$k}) { $update{$k} = int($user->{$k}); }
		} elsif ($_->{type} eq 'flag') {
			if ($user->{new_user})  { $update{$k} = 0; }
			if (exists $user->{$k}) { $update{$k} = $user->{$k} ? 1 : 0; }
		} else {
			if ($user->{new_user})  { $update{$k} = ''; }
			if (exists $user->{$k}) {
				$update{$k} = $user->{$k};
				if ($_->{_notag})  { $update{$k} =~ s/[<>\"\']//g; }
				if ($_->{_nocrlf}) { $update{$k} =~ s/[\r\n]//g;   }
			}
		}
	}

	return \%update;
}

#------------------------------------------------------------------------------
# ●ユーザーデータのアップデート
#------------------------------------------------------------------------------
sub update_user_data {
	my ($self, $_update) = @_;
	my $ROBJ = $self->{ROBJ};
	$ROBJ->clear_form_err();

	my $id = $_update->{id};
	my $update = $self->check_user_data($_update);

	# エラー終了
	my $errs = $ROBJ->form_err();
	if (!$update || $errs) {
		return { ret=>10, errs => $errs };
	}

	my $DB = $self->{DB};
	my $r  = $DB->update_match( $self->{table}, $update, 'id', $id);
	if ($r != 1) {
		return { ret=>-1, msg => 'DB update error' };
	}

	$self->log_save($id, 'update');
	return { ret => 0 };
}

#------------------------------------------------------------------------------
# ●パスワードを確認する
#------------------------------------------------------------------------------
sub check_pass_by_id {
	my ($self, $id, $pass) = @_;
	my $DB = $self->{DB};
	
	my $db = $DB->select($self->{table}, {
		cols => ['pass'],
		match => {id => $id},
		limit => 1
	});
	if (! @$db || $db->[0]->{'pass'} eq '*') { return; }
	return $self->check_pass($db->[0]->{'pass'}, $pass);
}

#------------------------------------------------------------------------------
# ●sudo機能
#------------------------------------------------------------------------------
sub sudo {
	my $self = shift;
	my $func = shift;
	my @bak = ($self->{ok}, $self->{isadmin});
	$self->{ok} = $self->{isadmin} = 1;
	my $r = $self->$func(@_);
	($self->{ok}, $self->{isadmin}) = @bak;
	return $r;
}

###############################################################################
# ■ユーザーデータベースの作成
###############################################################################
sub create_user_table {
	my $self  = shift;
	my $DB    = $self->{DB};
	my $table = $self->{table};

	$DB->begin();

	my %cols;
	$cols{text}    = [ qw(id name pass email) ];
	$cols{int}     = [ qw(login_c login_tm fail_c fail_tm) ];
	$cols{flag}    = [ qw(disable isadmin) ];
	$cols{idx}     = [ qw(id email isadmin) ];
	$cols{unique}  = [ qw(id email) ];
	$cols{notnull} = [ qw(id name) ];
	$DB->create_table_wrapper($table, \%cols, $self->{extcol});

	undef %cols;
	$cols{text}    = [ qw(id sid) ];
	$cols{int}     = [ qw(login_tm) ];
	$cols{flag}    = [ qw() ];
	$cols{idx}     = [ qw(id sid login_tm) ];
	$cols{unique}  = [ qw() ];
	$cols{notnull} = [ qw(id sid login_tm) ];
	$cols{ref}     = { id => "$table.id" };
	$DB->create_table_wrapper("${table}_sid", \%cols);

	undef %cols;
	$cols{text}    = [ qw(id type msg ip host agent) ];
	$cols{int}     = [ qw(tm) ];
	$cols{flag}    = [ qw() ];
	$cols{idx}     = [ qw(id type ip tm) ];
	$cols{unique}  = [ qw() ];
	$cols{notnull} = [ qw(tm) ];
	# 不正IDを記録できるように、参照制約は付けない
	# $cols{ref}     = { id => "$table.id" };
	$DB->create_table_wrapper("${table}_log", \%cols);

	$DB->commit();
}

1;
