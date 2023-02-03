/******************************************************************************
 * Copyright 2022 TypeFox GmbH
 * This program and the accompanying materials are made available under the
 * terms of the MIT License, which is available in the project root.
 ******************************************************************************/
package io.typefox.xtext2langium

import java.nio.file.Path
import java.nio.file.Paths
import java.util.List
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EEnum
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend2.lib.StringConcatenation
import org.eclipse.xtend2.lib.StringConcatenationClient
import org.eclipse.xtext.AbstractNegatedToken
import org.eclipse.xtext.Action
import org.eclipse.xtext.Alternatives
import org.eclipse.xtext.Assignment
import org.eclipse.xtext.CharacterRange
import org.eclipse.xtext.Conjunction
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.Disjunction
import org.eclipse.xtext.EOF
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.EnumLiteralDeclaration
import org.eclipse.xtext.EnumRule
import org.eclipse.xtext.GeneratedMetamodel
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.Group
import org.eclipse.xtext.Keyword
import org.eclipse.xtext.LiteralCondition
import org.eclipse.xtext.NamedArgument
import org.eclipse.xtext.Negation
import org.eclipse.xtext.ParameterReference
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
import org.eclipse.emf.ecore.EDataType

class Xtext2LangiumFragment extends AbstractXtextGeneratorFragment {
	static val Logger LOG = Logger.getLogger(Xtext2LangiumFragment)

	@Accessors(PUBLIC_SETTER)
	String outputPath

	/**
	 * If true, enum literal types will be prefixed with the enum type name to avoid name conflicts with other enum literals. Default is true.<br><br>
	 * <code>enum Color: RED;</code> <br>will create:<br><code>Color returns Color: Color_RED;<br>
	 * Color_RED returns string: 'RED';</code>
	 */
	@Accessors(PUBLIC_SETTER)
	boolean prefixEnumLiterals = true

	/**
	 * If true, Enum types will be handled as strings. Only relevant for generated metamodels. Default is false.<br>
	 */
	@Accessors(PUBLIC_SETTER)
	boolean useStringAsEnumRuleType = false

	/**
	 * If true, types from the ecore metamodel will also be generated.<br>
	 * If false, ecore data types will be replaced with Langium data types.
	 * Types that are not convertable to Langium built in types will be generated as string.<br>
	 * Default is false.<br>
	 */
	@Accessors(PUBLIC_SETTER)
	boolean generateEcoreTypes = false

	static val INDENT = '    '

	extension Utils utils = createUtils()

	protected def createUtils() {
		new Utils()
	}

	override generate() {
		if (outputPath === null) {
			LOG.error("Property 'outputPath' must be set.")
			return
		}
		generateGrammar(grammar, null)
	}

// -------------------- GRAMMAR --------------------
	def protected void generateGrammar(Grammar grammarToGenerate, Grammar subGrammar) {
		grammarToGenerate.usedGrammars.forEach [ superGrammar |
			generateGrammar(superGrammar, grammarToGenerate)
		]
		val ctx = new TransformationContext(grammarToGenerate, new StringConcatenation, generateEcoreTypes)
		var entryRuleCreated = false
		for (rule : grammarToGenerate.rules.filter [ rule |
			/* Filter out rules overwritten by the sub grammar */
			subGrammar === null || !subGrammar.rules.exists[name == rule.name]
		]) {
			if (rule.eClass === PARSER_RULE && !entryRuleCreated) {
				ctx.out.append('entry ')
				entryRuleCreated = true
			}
			processElement(rule, ctx)
		}

		val StringConcatenationClient imports = '''
			«FOR otherGrammar : grammarToGenerate.usedGrammars»
				import '«otherGrammar.eResource.URI.lastSegment.cutExtension»'
			«ENDFOR»
			«FOR metamodel : ctx.usedMetamodels»
				import '«metamodel.lastSegment.cutExtension»-types'
			«ENDFOR»
		'''

		val xtextFileName = grammarToGenerate.eResource.URI.lastSegment.cutExtension
		val writtenFile = writeToFile(Paths.get(outputPath, xtextFileName + '.langium'), '''
			««« Don't generate grammar name only if an entry parser rule exists. Otherwise Langium will complain. 
			«IF entryRuleCreated»
				grammar «ctx.grammarName»
			«ENDIF»
			«imports»
			
			«ctx.out»
		''')
		LOG.info('''Generated «writtenFile»''')

		generateTypes(ctx)
	}

	protected def void generateTypes(TransformationContext ctx) {
		for (metamodel : ctx.usedMetamodels) {
			val imports = newLinkedHashSet
			val checkImport = [ EClassifier eClass |
				if (eClass.EPackage.eResource.URI != metamodel && (ctx.generateEcoreTypes || !eClass.isEcoreType)) {
					imports.add(eClass.EPackage.eResource.URI.lastSegment.cutExtension)
				}
				return;
			]
			val checkImports = [ List<? extends EClassifier> types |
				types.forEach(checkImport)
				return types
			]
			val isReference = [ EStructuralFeature feature |
				return feature instanceof EReference && !(feature as EReference).isContainment &&
					!feature.EType.isEcoreType // ecore types are handled as primitives
			]
			val featureType = [EClassifier type|
				if(type instanceof EDataType && type.isEcoreType && generateEcoreTypes) type.name.idEscaper else langiumTypeName(type)
			]
			val isOptional = [ EStructuralFeature feature |
				return !feature.isRequired && !feature.isMany && langiumTypeName(feature.EType) != 'boolean'
			]
			val allTypes = '''
				«FOR type : ctx.types.get(metamodel)»
					«IF type instanceof EEnum»
						type «type.name.idEscaper» = «type.ELiterals.join(' | ')['''«enumLiteralName(type.name.idEscaper, it.name.idEscaper)»''']»;
						«FOR literal: type.ELiterals»
							type «enumLiteralName(type.name.idEscaper, literal.name.idEscaper)» = '«literal.literal»';
						«ENDFOR»
					«ELSE»
						type «type.name.idEscaper» = «if(!type.isEcoreType) 'string' else langiumTypeName(type)»;
					«ENDIF»
					
				«ENDFOR»
				«FOR _interface : ctx.interfaces.get(metamodel)»
					interface «_interface.name.idEscaper»«IF !_interface.ESuperTypes.empty» extends «checkImports.apply(_interface.ESuperTypes).join(', ')[name.idEscaper]»«ENDIF» {
						«FOR feature: _interface.EStructuralFeatures.filter[!it.transient]»
							«checkImport.apply(feature.EType)»
							«feature.name.idEscaper»«IF isOptional.apply(feature)»?«ENDIF»: «IF isReference.apply(feature)»@«ENDIF»«featureType.apply(feature.EType)»«IF feature.isMany»[]«ENDIF»
						«ENDFOR»
					}
					
				«ENDFOR»
			'''
			val typeFile = writeToFile(Path.of(outputPath, metamodel.lastSegment.cutExtension + '-types.langium'), '''
				«FOR _import : imports»
					import '«_import»-types'
				«ENDFOR»
				
				«allTypes»
			''')
			LOG.info('''Generated «typeFile»''')
		}
	}

	dispatch def protected void processElement(Object element, TransformationContext ctx) {
		ctx.out.append('''/* «element.class.simpleName» not handeled yet. */''')
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

		handleType(rule.type, ctx)
		
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

	dispatch def protected void processElement(EnumRule element, TransformationContext ctx) {
		val generatedEnum = element.type.metamodel instanceof GeneratedMetamodel
		val enumRuleName = element.name.idEscaper
		val enumLiteralDecls = if (element.alternatives instanceof EnumLiteralDeclaration) {
				#[element.alternatives as EnumLiteralDeclaration]
			} else if (element.alternatives instanceof Alternatives) {
				(element.alternatives as Alternatives).elements.filter(EnumLiteralDeclaration)
			}
		if (generatedEnum && !useStringAsEnumRuleType) {
			ctx.out.append('''
				type «enumRuleName» = «enumLiteralDecls.join(' | ')[enumLiteralString(it)]»;
			''')
		}
		ctx.out.append(enumRuleName)
		if (generatedEnum) {
			if (useStringAsEnumRuleType)
				ctx.out.append(' returns string')
			else {
				ctx.out.append(' returns ' + langiumTypeName(element.type.classifier))
			}
		} else {
			handleType(element.type, ctx)
		}
		ctx.out.append(':')
		ctx.out.newLine
		ctx.out.append(INDENT)

		ctx.out.append(enumLiteralDecls.join(' | ') [
			'''«enumLiteralName(enumRuleName, enumLiteral.name.idEscaper)»'''
		])
		ctx.out.newLine
		ctx.out.append(';')
		ctx.out.newLine
		// process enum literals as own rules
		enumLiteralDecls.forEach[processEnumLiteral(it, generatedEnum, ctx)]
		ctx.out.newLine
	}

	def protected void processEnumLiteral(EnumLiteralDeclaration element, boolean isGenerated,
		TransformationContext ctx) {
		val enumRuleName = (EcoreUtil2.getContainerOfType(element, EnumRule)?.name ?: element.enumLiteral.EEnum.name).
			idEscaper
		// need to qualify rule name with an Enumtype prefix because there can be conflicting literals in other enums
		val enumLitName = '''«enumLiteralName(enumRuleName, element.enumLiteral.name.idEscaper)»'''
		ctx.out.append('''«enumLitName» returns «(isGenerated || useStringAsEnumRuleType)?'string':enumLitName»: ''')
		if (element.literal !== null) {
			processElement(element.literal, ctx)
		} else {
			ctx.out.append(element.enumLiteral.name)
			ctx.out.append('''«»'«element.enumLiteral.name»'«»''')
		}
		ctx.out.append(";")

		ctx.out.newLine
	}

	dispatch def protected void processElement(Alternatives element, TransformationContext ctx) {
		val withParenthesis = needsParenthasis(element)
		if (withParenthesis)
			ctx.out.append('(')
		element.elements.processWithSeparator('| ', ctx)
		if (withParenthesis)
			ctx.out.append(')')
		ctx.out.append(element.cardinality)
	}

	dispatch def protected void processElement(Group element, TransformationContext ctx) {
		val withParenthesis = needsParenthasis(element)
		if (withParenthesis)
			ctx.out.append('(')
		if (element.guardCondition !== null) {
			ctx.out.append('<')
			processElement(element.guardCondition, ctx)
			ctx.out.append('> ')
		}
		element.elements.forEach [
			processElement(it, ctx)
		]
		if (withParenthesis)
			ctx.out.append(')')
		ctx.out.append(element.cardinality)
		ctx.out.append(' ')
	}

	dispatch def protected void processElement(RuleCall element, TransformationContext ctx) {
		if(element.rule === null) {
			throw new IllegalArgumentException('''Unresolved rule in RuleCall «NodeModelUtils.getTokenText(NodeModelUtils.getNode(element))».''')
		}
		ctx.out.append(element.rule.name.idEscaper)
		if (!element.arguments.empty) {
			ctx.out.append('<')
			element.arguments.processWithSeparator(', ', ctx)
			ctx.out.append('>')
		}
		if (element.cardinality !== null)
			ctx.out.append(element.cardinality)
		ctx.out.append(' ')
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
		ctx.addTypeIfReferenced(element)
	}

	dispatch def protected void processElement(Keyword element, TransformationContext ctx) {
		ctx.out.append(keywordToString(element))
		ctx.out.append(' ')
	}

	dispatch def protected void processElement(Wildcard element, TransformationContext ctx) {
		ctx.out.append('.')
	}

	dispatch def protected void processElement(CharacterRange element, TransformationContext ctx) {
		processElement(element.left, ctx)
		ctx.out.append('..')
		processElement(element.right, ctx)
		if (element.cardinality !== null)
			ctx.out.append(element.cardinality)
	}

	dispatch def protected void processElement(AbstractNegatedToken element, TransformationContext ctx) {
		switch (element.eClass) {
			case NEGATED_TOKEN: ctx.out.append(' !')
			case UNTIL_TOKEN: ctx.out.append(' -> ')
			default: ctx.out.append('''/* Not handled AbstractNegatedToken: «element.eClass» */''')
		}
		processElement(element.terminal, ctx)
	}

	dispatch def protected void processElement(EOF element, TransformationContext ctx) {
		ctx.out.append('UNSUPPORTED_EOF')
	}

	dispatch def protected void processElement(NamedArgument element, TransformationContext ctx) {
		if (element.calledByName) {
			ctx.out.append(element.parameter.name)
			ctx.out.append(' = ')
		}
		processElement(element.value, ctx)
	}

	dispatch def protected void processElement(ParameterReference element, TransformationContext ctx) {
		ctx.out.append(element.parameter.name)
	}

	dispatch def protected void processElement(Negation element, TransformationContext ctx) {
		ctx.out.append('!')
		processElement(element.value, ctx)
	}

	dispatch def protected void processElement(Disjunction element, TransformationContext ctx) {
		processElement(element.left, ctx)
		ctx.out.append(' | ')
		processElement(element.right, ctx)
	}

	dispatch def protected void processElement(Conjunction element, TransformationContext ctx) {
		processElement(element.left, ctx)
		ctx.out.append(' & ')
		processElement(element.right, ctx)
	}

	dispatch def protected void processElement(LiteralCondition element, TransformationContext ctx) {
		if (element.isTrue)
			ctx.out.append('true')
		else
			ctx.out.append('false')
	}

	protected def void handleType(TypeRef ref, TransformationContext context) {
		if (ref === null) {
			return
		}
		if (ref.classifier === null)
			throw new IllegalStateException(
				'''Unresolved Type reference at: «NodeModelUtils.getTokenText(NodeModelUtils.findActualNodeFor(ref.eContainer))»'''
			)
		if (ref.metamodel instanceof ReferencedMetamodel) {
			if (ref.eContainer.eClass !== ACTION)
				context.out.append(' returns ')
			val type = if(ref.classifier.isEcoreType && generateEcoreTypes) ref.classifier.name.idEscaper else langiumTypeName(ref.classifier)
			context.out.append(type)
		} else if (ref.metamodel instanceof GeneratedMetamodel) {
			if (ref.eContainer.eClass !== ACTION)
				context.out.append(' infers ')
			else
				context.out.append(' infer ')
			context.out.append(langiumTypeName(ref.classifier))
		}
		context.addTypeIfReferenced(ref)
	}

	protected def getGrammarName(TransformationContext ctx) {
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

	protected def String enumLiteralName(String enumName, String literalName) {
		if (prefixEnumLiterals)
			return '''«enumName»_«literalName»'''
		return literalName
	}

}
