/******************************************************************************
 * Copyright 2022 TypeFox GmbH
 * This program and the accompanying materials are made available under the
 * terms of the MIT License, which is available in the project root.
 ******************************************************************************/
package io.typefox.xtext2langium

import com.google.common.collect.LinkedHashMultimap
import com.google.common.io.Files
import java.io.File
import java.nio.charset.Charset
import java.util.List
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EPackage
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend2.lib.StringConcatenation
import org.eclipse.xtend2.lib.StringConcatenationClient
import org.eclipse.xtext.AbstractElement
import org.eclipse.xtext.AbstractNegatedToken
import org.eclipse.xtext.Action
import org.eclipse.xtext.Alternatives
import org.eclipse.xtext.Assignment
import org.eclipse.xtext.CharacterRange
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.EnumLiteralDeclaration
import org.eclipse.xtext.EnumRule
import org.eclipse.xtext.GeneratedMetamodel
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.GrammarUtil
import org.eclipse.xtext.Group
import org.eclipse.xtext.Keyword
import org.eclipse.xtext.ParserRule
import org.eclipse.xtext.ReferencedMetamodel
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.TypeRef
import org.eclipse.xtext.UnorderedGroup
import org.eclipse.xtext.Wildcard
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.xtext.generator.AbstractXtextGeneratorFragment

import static org.eclipse.xtext.XtextPackage.Literals.*
import org.eclipse.emf.ecore.EReference

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
		generateGrammar(grammar)
	}

	// -------------------- GRAMMAR --------------------
	def protected void generateGrammar(Grammar grammarToGenerate) {
		val ctx = new TransformationContext(grammarToGenerate, new StringConcatenation)
		processElement(ctx.grammar, ctx)

		val outPath = new File(outputPath)
		outPath.mkdirs
		val xtextFile = grammarToGenerate.eResource.URI.lastSegment.cutExtension
		val grammarFile = new File(outPath, xtextFile + '.langium')

		val StringConcatenationClient imports = '''
			«FOR metamodel : ctx.types.keySet»
				import '«metamodel.cutExtension»-types'
			«ENDFOR»
		'''
		Files.asCharSink(grammarFile, Charset.forName('UTF-8')).write('''
			grammar «ctx.grammarName»
			
			«imports»
			
			«ctx.out»
		''')
		LOG.info('''Generated «grammarFile»''')

		generateTypes(outPath, ctx)
	}

	protected def void generateTypes(File outPath, TransformationContext ctx) {
		for (metamodel : ctx.types.keySet) {
			val types = ctx.types.get(metamodel)
			val typeFile = new File(outPath, metamodel.cutExtension + '-types.langium')
			val allTypes = '''
				«FOR type : types»
					interface «type.name.idEscaper»«IF !type.ESuperTypes.empty» extends «type.ESuperTypes.join(', ')[name.idEscaper]»«ENDIF» {
						«FOR feature: type.EStructuralFeatures.filter[!it.transient]»
							«feature.name.idEscaper»«IF !feature.isRequired»?«ENDIF»: «IF feature instanceof EReference && !(feature as EReference).isContainment»@«ENDIF»«langiumTypeName(feature.EType)»«IF feature.isMany»[]«ENDIF»
						«ENDFOR»
					}
					
				«ENDFOR»
			'''
			Files.asCharSink(typeFile, Charset.forName('UTF-8')).write(allTypes)
			LOG.info('''Generated «typeFile»''')
		}
	}

	dispatch def protected void processElement(Object element, TransformationContext ctx) {
		ctx.out.append('''/* «element.class.simpleName» not handeled yet. */''')
	}

	dispatch def protected void processElement(Grammar grammar, TransformationContext ctx) {
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
		if (rule.wildcard) {
			ctx.out.append('*')
		}

		// TODO returns / infers
		if (GrammarUtil.isDatatypeRule(rule)) {
			ctx.out.append(' returns string')
		} else {
			handleType(rule.type, ctx)
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
		val langiumType = langiumTypeName(ref.classifier)
		if (ref.metamodel.EPackage.name == 'ecore') {
			context.out.append(' returns ' + langiumType)
		} else if (ref.metamodel instanceof ReferencedMetamodel) {
			if (ref.eContainer.eClass !== ACTION)
				context.out.append(' returns ')
			context.out.append(langiumType)
			context.addType(ref)
		} else if (ref.metamodel instanceof GeneratedMetamodel) {
			if (ref.eContainer.eClass !== ACTION)
				context.out.append(' infers ')
			else
				context.out.append(' infer ')
			context.out.append(langiumType)
		}
	}

	protected def langiumTypeName(EClassifier eClass) {
		if (eClass.EPackage.name == 'ecore') {
			// Date, bigint, boolean
			switch (eClass.name) {
				case 'EString':
					return 'string'
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
					return 'number'
				case 'EBigDecimal',
				case 'EBigInteger':
					return 'bigint'
				case 'EBooleanObject',
				case 'EBoolean':
					return 'boolean'
				case 'EDate':
					return 'Date'
				default:
					return 'string'
			}
		}
		return eClass.name.idEscaper

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
		ctx.addType(element.type)
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
		val withParenthesis = needsParenthasis(element)
		if (withParenthesis)
			ctx.out.append('(')
		element.elements.processWithSeparator('|', ctx)
		if (withParenthesis)
			ctx.out.append(')')
		ctx.out.append(element.cardinality)
	}

	dispatch def protected void processElement(Group element, TransformationContext ctx) {
		val withParenthesis = needsParenthasis(element)
		if (withParenthesis)
			ctx.out.append('(')
		element.elements.forEach [
			processElement(it, ctx)
		]
		if (withParenthesis)
			ctx.out.append(')')
		ctx.out.append(element.cardinality)
		ctx.out.append(' ')
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
		val withParenthesis = needsParenthasis(element)
		if (withParenthesis)
			ctx.out.append('(')
		ctx.out.append(element.feature.idEscaper)
		ctx.out.append(element.operator)
		processElement(element.terminal, ctx)
		if (withParenthesis)
			ctx.out.append(')')
		ctx.out.append(element.cardinality)
		ctx.out.append(' ')
	}

	dispatch def protected void processElement(Action element, TransformationContext ctx) {
		ctx.out.append('{')
		handleType(element.type, ctx)
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
		val withParenthesis = needsParenthasis(element)
		if (withParenthesis)
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
		if (withParenthesis)
			ctx.out.append(')')
		if (element.cardinality !== null) {
			ctx.out.append(element.cardinality)
		}
		ctx.out.newLine
		ctx.out.append(INDENT)
	}

	dispatch def protected void processElement(TypeRef element, TransformationContext ctx) {
		ctx.out.append(element.classifier.name.idEscaper)
		ctx.addType(element)
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

	protected var reservedWords = #{'Date', 'string', 'number', 'boolean', 'bigint', 'type', 'interface'}

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

	protected def String cutExtension(String fileName) {
		val lastDot = fileName.lastIndexOf('.')
		if (lastDot > 0)
			return fileName.substring(0, lastDot)
		return fileName
	}

	protected def boolean needsParenthasis(AbstractElement element) {
		val node = NodeModelUtils.findActualNodeFor(element)
		if (node !== null) {
			val text = NodeModelUtils.getTokenText(node).trim
			return text.startsWith('(') && if (element.cardinality !== null)
				text.charAt(text.length - 2) == ')'.charAt(0)
			else
				text.endsWith(')')
		}
		return true
	}
}

@Data
class TransformationContext {
	Grammar grammar
	StringConcatenation out
	val types = LinkedHashMultimap.<String, EClass>create

	def addType(TypeRef type) {
		doAddType(type.classifier.EPackage, type.classifier)
	}

	protected def void doAddType(EPackage metamodel, EClassifier classifier) {
		if (classifier instanceof EClass) {
			if (types.containsValue(classifier))
				return;
			types.put(metamodel.eResource.URI.lastSegment, classifier)
			classifier.ESuperTypes.forEach[type|
				doAddType(type.EPackage, classifier)
			]
			classifier.EReferences.forEach[ref|
				doAddType(ref.EReferenceType.EPackage, ref.EReferenceType)
			]
		} else {
			println('''Not handeled «classifier.name»''')
		}
	// ignore EDataType for now
	}
}
