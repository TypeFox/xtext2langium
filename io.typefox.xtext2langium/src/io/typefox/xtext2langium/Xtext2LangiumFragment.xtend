/******************************************************************************
 * Copyright 2022 TypeFox GmbH
 * This program and the accompanying materials are made available under the
 * terms of the MIT License, which is available in the project root.
 ******************************************************************************/
package io.typefox.xtext2langium

import com.google.common.io.Files
import java.io.File
import java.nio.charset.Charset
import java.util.List
import org.apache.log4j.Logger
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend2.lib.StringConcatenation
import org.eclipse.xtext.AbstractNegatedToken
import org.eclipse.xtext.Action
import org.eclipse.xtext.Alternatives
import org.eclipse.xtext.Assignment
import org.eclipse.xtext.CharacterRange
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.Group
import org.eclipse.xtext.Keyword
import org.eclipse.xtext.ParserRule
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.TypeRef
import org.eclipse.xtext.Wildcard
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.xtext.generator.AbstractXtextGeneratorFragment

import static org.eclipse.xtext.XtextPackage.Literals.*
import org.eclipse.xtext.UnorderedGroup
import org.eclipse.xtext.EnumRule
import org.eclipse.xtext.EnumLiteralDeclaration
import org.eclipse.xtext.GrammarUtil

class Xtext2LangiumFragment extends AbstractXtextGeneratorFragment {
	static val Logger LOG = Logger.getLogger(Xtext2LangiumFragment)

	@Accessors(PUBLIC_SETTER)
	String outputPath

	static val INDENT = '    '

	override generate() {
		if (outputPath === null || outputPath.length == 0) {
			LOG.error("Property 'outputPath' must be set.")
			return
		}
		val outFile = new File(outputPath)
		Files.asCharSink(outFile, Charset.forName('UTF-8')).write(langiumGrammar)
		LOG.info('''Generated «outFile»''')
	}

	// -------------------- GRAMMAR --------------------
	def protected CharSequence getLangiumGrammar() {
		val ctx = new TransformationContext(grammar, new StringConcatenation)
		processElement(ctx.grammar, ctx)
		return ctx.out
	}

	dispatch def protected void processElement(Object element, TransformationContext ctx) {
		ctx.out.append('''/* «element.class.simpleName» not handeled yet. */''')
	}

	dispatch def protected void processElement(Grammar grammar, TransformationContext ctx) {
		ctx.out.append('''grammar «ctx.grammarName»''')
		ctx.out.newLine
		var entryRuleCreated = false
		for (rule : grammar.rules) {
			if (rule.eClass === PARSER_RULE && !entryRuleCreated) {
				ctx.out.append('entry ')
				entryRuleCreated = true
			}
			processElement(rule, ctx)
		}
	/*
	 * for (superGrammar : grammar.usedGrammars) {
	 * 	out.createParserRules(superGrammar, false)
	 * }
	 * */
	}

	dispatch def protected void processElement(ParserRule rule, TransformationContext ctx) {
		if (rule.isFragment) {
			ctx.out.append('fragment ')
		}
		ctx.out.append(rule.name.idEscaper)

		if (!rule.parameters.empty) {
			ctx.out.append('<')
			var firstParam = true
			for (param : rule.parameters) {
				if (firstParam) {
					firstParam = false
				} else {
					ctx.out.append(', ')
				}
				ctx.out.append(param.name.idEscaper)
			}
			ctx.out.append('>')
		}

		// TODO returns / infers
		if (GrammarUtil.isDatatypeRule(rule)) {
			ctx.out.append(' returns string')
		}
		ctx.out.append(':')
		ctx.out.newLine
		ctx.out.append(INDENT)
		processElement(rule.alternatives, ctx)
		ctx.out.newLine
		ctx.out.append(';')
		ctx.out.newLine
		ctx.out.newLine
	}

	dispatch def protected void processElement(TerminalRule element, TransformationContext ctx) {
		ctx.out.
			append('''«IF ctx.grammar.hiddenTokens.exists[hidden| hidden.name == element.name]»hidden «ENDIF»terminal «element.name.idEscaper»''')
		handleType(element.type, ctx)
		ctx.out.append(':')
		element.alternatives.processElement(ctx)
		ctx.out.append(';')
		ctx.out.newLine
	}

	protected def handleType(TypeRef ref, TransformationContext context) {
		if (ref === null) {
			return
		}
		if (ref.metamodel.EPackage.name == 'ecore') {
			// Date, bigint, boolean
			switch (ref.classifier.name) {
				case 'EString':
					context.out.append(' returns string')
				case 'EByte',
				case 'EByteObject',
				case 'EDouble',
				case 'EDoubleObject',
				case 'EFloat',
				case 'EFloatObject',
				case 'ELong',
				case 'ELongObject',
				case 'EShort',
				case 'EShortObject',
				case 'EInt',
				case 'EIntegerObject':
					context.out.append(' returns number')
				case 'EBigDecimal',
				case 'EBigInteger':
					context.out.append(' returns bigint')
				case 'EBooleanObject',
				case 'EBoolean':
					context.out.append(' returns boolean')
				case 'EDate':
					context.out.append(' returns Date')
				default:
					context.out.append(' returns string')
			}
		} else {
			context.out.append(' returns string')
		}
	}

	dispatch def protected void processElement(EnumRule element, TransformationContext ctx) {
		ctx.out.append('''«element.name.idEscaper»:''')
		ctx.out.newLine
		ctx.out.append(INDENT)
		element.alternatives.processElement(ctx)
		ctx.out.newLine
		ctx.out.append(';')
		ctx.out.newLine
		ctx.out.newLine
	}

	dispatch def protected void processElement(EnumLiteralDeclaration element, TransformationContext ctx) {
		ctx.out.append(element.enumLiteral.name.idEscaper)
		ctx.out.append(' =')
		if (element.literal !== null) {
			element.literal.processElement(ctx)
		} else {
			ctx.out.append("'")
			ctx.out.append(element.enumLiteral.name.idEscaper)
			ctx.out.append("'")
		}
	}

	dispatch def protected void processElement(Alternatives element, TransformationContext ctx) {
		ctx.out.append('(')
		element.elements.processWithSeparator('|', ctx)
		ctx.out.append(')')
		ctx.out.append(element.cardinality)
	}

	dispatch def protected void processElement(Group element, TransformationContext ctx) {
		ctx.out.append('(')
		element.elements.forEach [
			processElement(it, ctx)
		]
		ctx.out.append(')')
		ctx.out.append(element.cardinality)
	}

	dispatch def protected void processElement(RuleCall element, TransformationContext ctx) {
		ctx.out.append(element.rule.name.idEscaper)
		if (!element.arguments.empty) {
			ctx.out.append('<')
			element.arguments.processWithSeparator(', ', ctx)
			ctx.out.append('>')
		}
	}

	dispatch def protected void processElement(Assignment element, TransformationContext ctx) {
		ctx.out.append(element.feature.idEscaper)
		ctx.out.append(element.operator)
		processElement(element.terminal, ctx)
		ctx.out.append(' ')
	}

	dispatch def protected void processElement(Action element, TransformationContext ctx) {
		ctx.out.append('{infer ')
		processElement(element.type, ctx)
		if (element.feature !== null) {
			ctx.out.append('.')
			ctx.out.append(element.feature)
			ctx.out.append(element.operator)
			ctx.out.append('current')
		}
		ctx.out.append('} ')
	}

	dispatch def protected void processElement(CrossReference element, TransformationContext ctx) {
		ctx.out.append('[')
		processElement(element.type, ctx)
		if (element.terminal !== null) {
			ctx.out.append(':')
			processElement(element.terminal, ctx)
		}
		ctx.out.append(']')
	}

	dispatch def protected void processElement(UnorderedGroup element, TransformationContext ctx) {
		ctx.out.newLine
		ctx.out.append(INDENT)
		ctx.out.append('(')
		ctx.out.newLine
		ctx.out.append(INDENT)
		ctx.out.append(INDENT)
		ctx.out.append(' ')
		element.elements.processWithSeparator([ out |
			out.newLine
			out.append(INDENT)
			out.append(INDENT)
			out.append('&')
		], ctx)

		ctx.out.newLine
		ctx.out.append(INDENT)
		ctx.out.append(')')
		if (element.cardinality !== null) {
			ctx.out.append(element.cardinality)
		}
		ctx.out.newLine
		ctx.out.append(INDENT)
	}

	dispatch def protected void processElement(TypeRef element, TransformationContext ctx) {
		ctx.out.append(element.classifier.name.idEscaper)
	}

	dispatch def protected void processElement(Keyword element, TransformationContext ctx) {
		ctx.out.append(' ')
		// TODO handle escaped values like '\n'
		val node = NodeModelUtils.getNode(element)
		if (node !== null) {
			ctx.out.append(NodeModelUtils.getTokenText(node))
		} else {
			ctx.out.append("'")
			ctx.out.append(element.value)
			ctx.out.append("'")
		}
		ctx.out.append(' ')
	}

	dispatch def protected void processElement(Wildcard element, TransformationContext ctx) {
		ctx.out.append('*')
	}

	dispatch def protected void processElement(CharacterRange element, TransformationContext ctx) {
		processElement(element.left, ctx)
		ctx.out.append('..')
		processElement(element.right, ctx)
	}

	dispatch def protected void processElement(AbstractNegatedToken element, TransformationContext ctx) {
		switch (element.eClass) {
			case NEGATED_TOKEN: ctx.out.append(' !')
			case UNTIL_TOKEN: ctx.out.append(' -> ')
			default: ctx.out.append('''/* Not handled AbstractNegatedToken: «element.eClass» */''')
		}
		processElement(element.terminal, ctx)
	}

	protected var reservedWords = #{'Date', 'string', 'number', 'boolean', 'bigint'}

	protected def idEscaper(String id) {
		if (reservedWords.contains(id))
			return '^' + id
		return id
	}

	def protected getGrammarName(TransformationContext ctx) {
		val name = ctx.grammar.name
		val dotIndex = name.lastIndexOf('.')
		return name.substring(dotIndex + 1).idEscaper
	}

	protected def void processWithSeparator(List<?> elements, String separator, TransformationContext ctx) {
		elements.processWithSeparator([it.append(separator)], ctx)
	}

	protected def void processWithSeparator(List<?> elements, (StringConcatenation)=>void appender,
		TransformationContext ctx) {
		val iterator = elements.listIterator
		iterator.forEach [
			processElement(it, ctx)
			if (iterator.hasNext) {
				appender.apply(ctx.out)
			}
		]
	}
}

@Data
class TransformationContext {
	Grammar grammar
	StringConcatenation out
}
