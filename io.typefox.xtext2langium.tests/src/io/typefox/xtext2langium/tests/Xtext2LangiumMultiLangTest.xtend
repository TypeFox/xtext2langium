package io.typefox.xtext2langium.tests

import org.eclipse.xtext.resource.XtextResourceSet
import org.junit.Before
import org.junit.Test

class Xtext2LangiumMultiLangTest extends AbstractXtext2LangiumTest {

	var XtextResourceSet sharedResourceSet = null

	@Before
	def void setup() {
		sharedResourceSet = null
	}

	override <T> get(Class<T> clazz) {
		if (clazz === XtextResourceSet) {
			if (sharedResourceSet === null) {
				sharedResourceSet = super.get(clazz) as XtextResourceSet
			}
			return sharedResourceSet as T
		}
		return super.<T>get(clazz)
	}

	@Test
	def void testTerminals_01() {
		'''
			grammar io.typefox.xtext2langium.Test with org.eclipse.xtext.common.Terminals
			generate xtext2langiumTest 'http://Xtext2LangiumTest'
			import "http://www.eclipse.org/emf/2002/Ecore" as ecore
			
			@Override 
			terminal ID: '^'?('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'_'|'0'..'9')*;
			@Override 
			terminal INT returns ecore::EInt: ('0'..'9')+;
		'''.assertGeneratedLangium('''
			import 'Terminals'
			
			terminal ID returns string:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns number:'0' ..'9' +;
		''')
		assertGeneratedFile('Terminals.langium', '''
			
			terminal ID returns string:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns number:'0' ..'9' +;
			terminal STRING returns string:'"' ('\\' . |  !('\\' | '"' ))*'"'  | "'" ('\\' . |  !('\\' | "'" ))*"'"  ;
			hidden terminal ML_COMMENT returns string:'/*'  -> '*/'  ;
			hidden terminal SL_COMMENT returns string:'//'  !('\n' | '\r' )('\r'? '\n' )?  ;
			hidden terminal WS returns string:(' ' | '\t' | '\r' | '\n' )+;
			terminal ANY_OTHER returns string:.;
		''')
	}
	@Test
	def void testTerminals_02() {
		'''
			grammar io.typefox.xtext2langium.Test with org.eclipse.xtext.common.Terminals
			generate xtext2langiumTest 'http://Xtext2LangiumTest'
			import "http://www.eclipse.org/emf/2002/Ecore" as ecore
			
			@Override 
			terminal ID: '^'?('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'_'|'0'..'9')*;
			@Override 
			terminal INT returns ecore::EInt: ('0'..'9')+;
		'''.assertGeneratedLangium('''
			import 'Terminals'
			
			terminal ID returns string:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns number:'0' ..'9' +;
		''', [removeOverridenRules = true])
		assertGeneratedFile('Terminals.langium', '''
			
			terminal STRING returns string:'"' ('\\' . |  !('\\' | '"' ))*'"'  | "'" ('\\' . |  !('\\' | "'" ))*"'"  ;
			hidden terminal ML_COMMENT returns string:'/*'  -> '*/'  ;
			hidden terminal SL_COMMENT returns string:'//'  !('\n' | '\r' )('\r'? '\n' )?  ;
			hidden terminal WS returns string:(' ' | '\t' | '\r' | '\n' )+;
			terminal ANY_OTHER returns string:.;
		''')
	}

	@Test
	def void testMultipleGrammars_01() {
		getResource('''
			grammar org.xtext2langium.Uddl with org.eclipse.xtext.common.Terminals
			
			generate uddl "http://www.xtext2langium.org/Uddl"
			
			Model:
				greetings+=Greeting*;
				
			Greeting:
				'Hello' name=ID '!';
			
		''', 'uddl.xtext')

		val faceGrammar = getResource('''
			grammar org.xtext2langium.Face with org.xtext2langium.Uddl
			
			generate face "http://www.xtext2langium.org/Face"
			
			import "http://www.xtext2langium.org/Uddl" as uddl
			
			@Override 
			Model:
				greetings+=Uddl::Greeting*;
		''', TEST_GRAMMAR_NAME)

		faceGrammar.assertGeneratedLangium('''
			grammar Face
			import 'uddl'
			
			entry Model infers Model:
			    greetings+=Greeting * 
			;
			
		''', [conf | conf.removeOverridenRules = true])
		assertGeneratedFile('uddl.langium', '''
			grammar Uddl
			import 'Terminals'
			
			entry Greeting infers Greeting:
			    'Hello' name=ID  '!'  
			;
			
		''')
		assertGeneratedFile('Terminals.langium', '''
			
			terminal ID returns string:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns number:'0' ..'9' +;
			terminal STRING returns string:'"' ('\\' . |  !('\\' | '"' ))*'"'  | "'" ('\\' . |  !('\\' | "'" ))*"'"  ;
			hidden terminal ML_COMMENT returns string:'/*'  -> '*/'  ;
			hidden terminal SL_COMMENT returns string:'//'  !('\n' | '\r' )('\r'? '\n' )?  ;
			hidden terminal WS returns string:(' ' | '\t' | '\r' | '\n' )+;
			terminal ANY_OTHER returns string:.;
		''')
	}

}
