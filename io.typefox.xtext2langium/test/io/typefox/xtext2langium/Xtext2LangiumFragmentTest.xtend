package io.typefox.xtext2langium

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

}
