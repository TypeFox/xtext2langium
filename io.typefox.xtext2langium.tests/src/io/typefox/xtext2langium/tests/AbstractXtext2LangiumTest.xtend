package io.typefox.xtext2langium.tests

import io.typefox.xtext2langium.Utils
import io.typefox.xtext2langium.Xtext2LangiumFragment
import java.nio.file.Path
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.XtextStandaloneSetup

abstract class AbstractXtext2LangiumTest extends AbstractXtextTests {
	val generated = <String, String>newLinkedHashMap

	protected val TEST_GRAMMAR_NAME = 'mytestmodel.langium'

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
		assertGeneratedLangium(
			getResourceFromStringAndExpect(xtextGrammar.toString, AbstractXtextTests.UNKNOWN_EXPECTATION), expected,
			configs)
	}

	protected def assertGeneratedLangium(Resource grammarResource, String expected) {
		assertGeneratedLangium(grammarResource, expected, [])
	}

	protected def assertGeneratedLangium(Resource grammarResource, String expected,
		(Xtext2LangiumFragment)=>void configs) {
		runFragment(grammarResource, configs)
		assertGeneratedFile(TEST_GRAMMAR_NAME, expected)
	}

	protected def void assertGeneratedFile(String fileName, String content) {
		assertEquals(content, generated.get(fileName))
	}

	protected def void runFragment(Resource grammarResource, (Xtext2LangiumFragment)=>void configs) {

		val fragment = new Xtext2LangiumFragment() {

			override protected getGrammar() {
				grammarResource.contents.head as Grammar
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
