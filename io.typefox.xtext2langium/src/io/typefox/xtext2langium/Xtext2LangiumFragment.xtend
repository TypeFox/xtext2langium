/******************************************************************************
 * Copyright 2022 TypeFox GmbH
 * This program and the accompanying materials are made available under the
 * terms of the MIT License, which is available in the project root.
 ******************************************************************************/
package io.typefox.xtext2langium

import org.eclipse.xtext.xtext.generator.AbstractXtextGeneratorFragment
import org.eclipse.xtend.lib.annotations.Accessors
import com.google.common.io.Files
import java.io.File
import java.nio.charset.Charset
import org.eclipse.xtend2.lib.StringConcatenation
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.ParserRule
import org.eclipse.xtext.AbstractElement

class Xtext2LangiumFragment extends AbstractXtextGeneratorFragment {
	
	@Accessors(PUBLIC_SETTER)
	String outputPath
	
	static val INDENT = '    '
	
	override generate() {
		if (outputPath === null || outputPath.length == 0) {
			System.err.println("Property 'outputPath' must be set.")
			return
		}
		Files.asCharSink(new File(outputPath), Charset.forName('UTF-8')).write(langiumGrammar)
	}
	
	
	//-------------------- GRAMMAR --------------------
	
	def protected CharSequence getLangiumGrammar() {
		val out = new StringConcatenation
		out.append('''grammar «grammarName»''')
		out.newLine
		out.createParserRules(grammar, true)
		return out
	}
	
	def protected getGrammarName() {
		val name = grammar.name
		val dotIndex = name.lastIndexOf('.')
		return name.substring(dotIndex + 1)
	}
	
	def protected void createParserRules(StringConcatenation out, Grammar grammar, boolean first) {
		var isFirst = first
		for (rule : grammar.rules.filter(ParserRule)) {
			if (isFirst) {
				out.append('entry ')
				isFirst = false
			}
			out.createParserRule(rule)
		}
		for (superGrammar : grammar.usedGrammars) {
			out.createParserRules(superGrammar, false)
		}
	}
	
	def protected void createParserRule(StringConcatenation out, ParserRule rule) {
		if (rule.isFragment) {
			out.append('fragment ')
		}
		out.append(rule.name)
		
		if (!rule.parameters.empty) {
			out.append('<')
			var firstParam = true
			for (param : rule.parameters) {
				if (firstParam) {
					firstParam = false
				} else {
					out.append(', ')
				}
				out.append(param.name)
			}
			out.append('>')
		}
		
		// TODO returns / infers
		
		out.append(':')
		out.newLine
		out.append(INDENT)
		out.createRuleElement(rule.alternatives)
	}
	
	def protected void createRuleElement(StringConcatenation out, AbstractElement element) {
		// TODO
	}
	
}