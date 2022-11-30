package io.typefox.xtext2langium

import java.nio.file.Path
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.XtextStandaloneSetup
import org.junit.Test

class Xtext2LangiumFragmentTest extends AbstractXtextTests {

	val generated = <String, String>newLinkedHashMap

	val TEST_GRAMMAR_NAME = 'mytestmodel.langium'

	override void setUp() throws Exception {
		super.setUp();
		with(XtextStandaloneSetup);
		generated.clear
	}

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
	

	private def assertGeneratedLangium(CharSequence xtextGrammar, String expected) {
		assertGeneratedLangium(xtextGrammar, expected, [])
	}

	private def assertGeneratedLangium(CharSequence xtextGrammar, String expected,
		(Xtext2LangiumFragment)=>void configs) {
		runFragment('''
			grammar io.typefox.xtext2langium.FragmentTest
			generate fragmentTest 'http://FragmentTest'
			import "http://www.eclipse.org/emf/2002/Ecore" as ecore
			«xtextGrammar»
		'''.toString, configs)
		assertEquals(expected, generated.get(TEST_GRAMMAR_NAME))
	}

	private def void runFragment(String grammar, (Xtext2LangiumFragment)=>void configs) {
		val resource = getResourceFromStringAndExpect(grammar, AbstractXtextTests.UNKNOWN_EXPECTATION);
		val fragment = new Xtext2LangiumFragment() {

			override protected getGrammar() {
				resource.contents.head as Grammar
			}

			override protected writeToFile(Path path, CharSequence content) {
				generated.put(path.fileName.toString, content.toString)
				return path.fileName.toString
			}

		} => [
			outputPath = ''
		]
		configs.apply(fragment)
		fragment.generate
	}
}
