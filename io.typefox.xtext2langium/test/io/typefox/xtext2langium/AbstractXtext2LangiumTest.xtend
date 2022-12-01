package io.typefox.xtext2langium

import java.nio.file.Path
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.XtextStandaloneSetup

abstract class AbstractXtext2LangiumTest extends AbstractXtextTests {
	val generated = <String, String>newLinkedHashMap

	val TEST_GRAMMAR_NAME = 'mytestmodel.langium'

	override void setUp() throws Exception {
		super.setUp();
		with(XtextStandaloneSetup);
		generated.clear
	}

	protected def assertGeneratedLangium(CharSequence xtextGrammar, String expected) {
		assertGeneratedLangium(xtextGrammar, expected, [])
	}

	protected def assertGeneratedLangium(CharSequence xtextGrammar, String expected,
		(Xtext2LangiumFragment)=>void configs) {
		runFragment('''
			«grammarHeader()»
			«xtextGrammar»
		'''.toString, configs)
		assertGeneratedFile(TEST_GRAMMAR_NAME, expected)
	}

	protected def void assertGeneratedFile(String fileName, String content) {
		assertEquals(content, generated.get(fileName))
	}

	protected def String grammarHeader() '''
		grammar io.typefox.xtext2langium.FragmentTest
		generate fragmentTest 'http://FragmentTest'
		import "http://www.eclipse.org/emf/2002/Ecore" as ecore
	'''

	protected def void runFragment(String grammar, (Xtext2LangiumFragment)=>void configs) {
		val resource = getResourceFromStringAndExpect(grammar, AbstractXtextTests.UNKNOWN_EXPECTATION);
		val fragment = new Xtext2LangiumFragment() {

			override protected getGrammar() {
				resource.contents.head as Grammar
			}

			override protected createUtils() {
				new Utils() {
					override writeToFile(Path path, CharSequence content) {
						generated.put(path.fileName.toString, content.toString)
						return path.fileName.toString
					}
				}
			}

		} => [
			outputPath = ''
		]
		configs.apply(fragment)
		fragment.generate
	}
}
