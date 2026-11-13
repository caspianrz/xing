package xing.template;

import haxe.Exception;
import haxe.ds.ReadOnlyArray;
import haxe.exceptions.NotImplementedException;
import sys.io.File;
import xing.template.XingIRVirtualMachine;

abstract Template(XingIRVirtualMachine) {
	function new(template:String, context:Context) {
		try {
			final lexer:Lexer = new Lexer(template);
			final tokens:Array<Token> = lexer.scanTokens();
			final parser:Parser = new Parser(tokens);
			final xingCode:Statement = parser.parse();
			final analyzer:XingCodeAnalyzer = new XingCodeAnalyzer(xingCode);
			this = new XingIRVirtualMachine(analyzer.ir);
			this.switchContext(context);
		} catch (e:Exception) {
			throw e;
		}
	}

	public function switchContext(context:Context) {
		this.switchContext(context);
	}

	public static function fromPath(path:String, context:Context) {
		return new Template(File.getContent(path), context);
	}

	public static function fromString(template:String, context:Context) {
		return new Template(template, context);
	}

	@:to
	private function toString():String {
		return this.output;
	}
}
