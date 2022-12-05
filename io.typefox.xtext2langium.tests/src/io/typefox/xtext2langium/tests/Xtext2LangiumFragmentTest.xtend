package io.typefox.xtext2langium.tests

import org.junit.Test

class Xtext2LangiumFragmentTest extends AbstractXtext2LangiumTest {

	@Test
	def void testEnumExtends_01() {
		'''
			enum EnumType returns EnumType:
				FOO |
				BAR;
			
			enum EnumType2 returns EnumType:
				FOO="FOO2" |
				BAR="BAR2";
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			
			EnumType returns string:
			    EnumType_FOO | EnumType_BAR
			;
			EnumType_FOO returns string: 'FOO' ;
			EnumType_BAR returns string: 'BAR' ;
			
			EnumType2 returns string:
			    EnumType2_FOO | EnumType2_BAR
			;
			EnumType2_FOO returns string: "FOO2" ;
			EnumType2_BAR returns string: "BAR2" ;
			
		''', [useStringAsEnumRuleType = true])

	}

	@Test
	def void testEnumExtends_02() {
		'''
			enum EnumType returns EnumType:
				FOO="FOO" |
				BAR="BAR";
			
			enum EnumType2 returns EnumType:
				FOO="FOO2" |
				BAR="BAR2";
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			
			type EnumType = "FOO" | "BAR";
			EnumType returns EnumType:
			    EnumType_FOO | EnumType_BAR
			;
			EnumType_FOO returns string: "FOO" ;
			EnumType_BAR returns string: "BAR" ;
			
			type EnumType2 = "FOO2" | "BAR2";
			EnumType2 returns EnumType:
			    EnumType2_FOO | EnumType2_BAR
			;
			EnumType2_FOO returns string: "FOO2" ;
			EnumType2_BAR returns string: "BAR2" ;
			
		''')

	}

	@Test
	def void testEnumPrefix_01() {
		'''
			enum EnumType returns EnumType:
				FOO="FOO" |
				BAR="BAR";
			
			enum EnumType2 returns EnumType:
				FOO="FOO2" |
				BAR="BAR2";
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			
			type EnumType = "FOO" | "BAR";
			EnumType returns EnumType:
			    FOO | BAR
			;
			FOO returns string: "FOO" ;
			BAR returns string: "BAR" ;
			
			type EnumType2 = "FOO2" | "BAR2";
			EnumType2 returns EnumType:
			    FOO | BAR
			;
			FOO returns string: "FOO2" ;
			BAR returns string: "BAR2" ;
			
		''', [prefixEnumLiterals = false])

	}

	@Test
	def void testTerminals_01() {
		'''
			terminal TEXT:
				('`' | EOF); // EOF not supported // EOF not supported
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			
			terminal TEXT returns string:('`' | UNSUPPORTED_EOF);
		''')
	}

	@Test
	def void testParameterizedRule_01() {
		'''
			Model <param4>:
				ConditionalFragment<param1 = param4, param2 = !false>
				ConditionalFragment< true | false, !false & true>
			;
			
			fragment ConditionalFragment<param1, param2>:
				<param1 & param2 | !param1> name = 'Foo' |
				<param2> name = 'Bar'
			;
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			
			entry Model<param4> infers Model:
			    ConditionalFragment<param1 = param4, param2 = !false> ConditionalFragment<true | false, !false & true>  
			;
			
			fragment ConditionalFragment<param1, param2> infers ConditionalFragment:
			    <param1 & param2 | !param1> name='Foo'   | <param2> name='Bar'   
			;
			
		''')
	}

	@Test
	def void testEcoreGeneration_on() {
		'''
			Model:
				name=ID
				date=DATE
				age=INT;
			
			@Override
			terminal ID returns ecore::EString:
				'^'? ('a'..'z' | 'A'..'Z' | '_') ('a'..'z' | 'A'..'Z' | '_' | '0'..'9')*;
			
			terminal  DATE returns ecore::EDate:
				'^'? ('a'..'z' | 'A'..'Z' | '_') ('a'..'z' | 'A'..'Z' | '_' | '0'..'9')*;
			
			@Override
			terminal INT returns ecore::EInt:
				('0'..'9')+;
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			import 'Ecore-types'
			
			entry Model infers Model:
			    name=ID  date=DATE  age=INT   
			;
			
			terminal ID returns EString:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal DATE returns EDate:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns EInt:'0' ..'9' +;
		''', [generateEcoreTypes = true])
		assertGeneratedFile('Ecore-types.langium', '''
			
			type EString = string;
			
			type EDate = Date;
			
			type EInt = number;
			
		''')
	}

	@Test
	def void testEcoreGeneration_off() {
		'''
			Model:
				name=ID
				date=DATE
				age=INT;
			
			@Override
			terminal ID returns ecore::EString:
				'^'? ('a'..'z' | 'A'..'Z' | '_') ('a'..'z' | 'A'..'Z' | '_' | '0'..'9')*;
			
			terminal  DATE returns ecore::EDate:
				'^'? ('a'..'z' | 'A'..'Z' | '_') ('a'..'z' | 'A'..'Z' | '_' | '0'..'9')*;
			
			@Override
			terminal INT returns ecore::EInt:
				('0'..'9')+;
		'''.assertGeneratedLangium('''
			grammar FragmentTest
			
			entry Model infers Model:
			    name=ID  date=DATE  age=INT   
			;
			
			terminal ID returns string:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal DATE returns Date:'^'? ('a' ..'z' | 'A' ..'Z' | '_' )('a' ..'z' | 'A' ..'Z' | '_' | '0' ..'9' )* ;
			terminal INT returns number:'0' ..'9' +;
		''')
		assertGeneratedFile('Ecore-types.langium', null) // no ecore types generated
	}

}
