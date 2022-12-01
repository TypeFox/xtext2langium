package io.typefox.xtext2langium.tests

import org.junit.Test

class Xtext2LangiumFragmentMultiLangTest extends AbstractXtext2LangiumTest {

	@Test
	def void testTerminals_01() {
		'''
			@Override 
			terminal ID: '^'?('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'_'|'0'..'9')*;
			@Override 
			terminal INT returns ecore::EInt: ('0'..'9')+;
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			import 'Terminals'
			
			terminal ID returns string:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns number:'0' ..'9' +;
		''')
		assertGeneratedFile('Terminals.langium', '''
		
		terminal STRING returns string:'"' ('\\' . |  !('\\' | '"' ))*'"'  | "'" ('\\' . |  !('\\' | "'" ))*"'"  ;
		hidden terminal ML_COMMENT returns string:'/*'  -> '*/'  ;
		hidden terminal SL_COMMENT returns string:'//'  !('\n' | '\r' )('\r'? '\n' )?  ;
		hidden terminal WS returns string:(' ' | '\t' | '\r' | '\n' )+;
		terminal ANY_OTHER returns string:.;
		''')
	}

	override protected grammarHeader() {
		'''
			grammar io.typefox.xtext2langium.FragmentTest with org.eclipse.xtext.common.Terminals
			generate fragmentTest 'http://FragmentTest'
			import "http://www.eclipse.org/emf/2002/Ecore" as ecore
		'''
	}

}
