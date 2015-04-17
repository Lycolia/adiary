#!/usr/local/bin/perl
require 5.004;
use strict;
#-------------------------------------------------------------------------------
# �ѡ������ƤӽФ�
#					(C)2015 nabe@abk / ABK project
#-------------------------------------------------------------------------------
package SatsukiApp::parser;
use Satsuki::AutoLoader;
#-------------------------------------------------------------------------------
our $VERSION = '1.00';
###############################################################################
# �����ܽ���
###############################################################################
#------------------------------------------------------------------------------
# ���ڥ��󥹥ȥ饯����
#------------------------------------------------------------------------------
sub new {
	my ($class, $ROBJ, $self) = @_;
	if (ref($self) ne 'HASH') { $self={}; }
	bless($self, $class);	# $self �򤳤Υ��饹�ȴ�Ϣ�դ���
	$self->{ROBJ}    = $ROBJ;	# root object save
	return $self;
}

###############################################################################
# ���ᥤ�����
###############################################################################
sub main {
	my $self  = shift;
	my $r = $self->_main(@_);
	my $ROBJ = $self->{ROBJ};

	foreach(@{$ROBJ->{Message}}, @{$ROBJ->{Errors}}) {
		print $_,"\n";
	}
	return $r;
}

sub _main {
	my $self = shift;
	my $ROBJ = $self->{ROBJ};

	# �ѡ������Υ���
	my $parser = $self->load_parser( $self->{parser_type} );
	if (! ref($parser)) {
		$ROBJ->message("Load parser '%s' failed", $parser);
		return ;
	}
	$parser->{section_hnum} = $self->{section_hnum};

	my $argv = $ROBJ->{ARGV};
	if (!@$argv) {
		print "$0 (file)\n";
		return ;
	}

	my $frame = $self->{format_skel};
	foreach(@$argv) {
		my $file = $_ . '.html';
		if ($_ =~ /^(.*?)\.\w+$/) {
			$file = $1 . '.html';
		}

		print "process: $_ to $file\n";

		# �ѡ������ǽ���
		my $text = $ROBJ->fread_lines( $_ );
		map { s/\r\n|\r/\n/g } @$text;
		$text = join('', @$text);

		# preprocessoer
		if ($parser->{use_preprocessor} && $text ne '') {
			$parser->preprocessor( $text );
		}

		my ($text, $text_s) = $parser->text_parser( $text );

		# �ѡ��������ѿ���������
		$ROBJ->{vars} = $parser->{vars_} || {};

		# �ե졼���������
		my $out = $ROBJ->call( $frame, $text );

		# Ϣ��
		my $str = $ROBJ->chain_array($out);

		# �񤭽Ф�
		$ROBJ->fwrite_lines( $file, $str );
	}
}

#------------------------------------------------------------------------------
# ��parser�Υ���
#------------------------------------------------------------------------------
sub load_parser {
	my $self = shift;
	my $name = shift;
	if ($name =~ /\W/) { return; }
	return $self->{ROBJ}->call( '_parser/' . $name );
}

#------------------------------------------------------------------------------
# ��blog_dir�����
#------------------------------------------------------------------------------
sub blog_dir {
	return '';
}
sub blogpub_dir {
	return '';
}
sub blogimg_dir {
	return '';
}
