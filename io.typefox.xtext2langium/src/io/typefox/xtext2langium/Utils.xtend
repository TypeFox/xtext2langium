package io.typefox.xtext2langium

import com.google.common.io.Files
import java.io.File
import java.nio.charset.Charset
import java.nio.file.Path
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EcorePackage
import org.eclipse.xtext.AbstractElement
import org.eclipse.xtext.EnumLiteralDeclaration
import org.eclipse.xtext.Keyword
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

class Utils {

	def String writeToFile(Path path, CharSequence content) {
		val outPath = new File(path.parent.toString)
		if (!outPath.exists)
			outPath.mkdirs
		val grammarFile = path.toFile
		Files.asCharSink(grammarFile, Charset.forName('UTF-8')).write(content)
		return path.fileName.toString
	}

	def String cutExtension(String fileName) {
		val lastDot = fileName.lastIndexOf('.')
		if (lastDot > 0)
			return fileName.substring(0, lastDot)
		return fileName
	}

	protected var reservedWords = #{'Date', 'string', 'number', 'boolean', 'bigint', 'type', 'interface'}

	def idEscaper(String id) {
		if (reservedWords.contains(id))
			return '^' + id
		return id
	}

	protected def langiumTypeName(EClassifier eClass) {
		if (eClass.isEcoreType) {
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

	def boolean needsParenthasis(AbstractElement element) {
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

	def boolean isEcoreType(EClassifier classifier) {
		classifier.EPackage.nsURI == EcorePackage.eINSTANCE.nsURI
	}

	def String enumLiteralString(EnumLiteralDeclaration element) {
		if (element.literal !== null) {
			return keywordToString(element.literal)
		} else {
			return '''«element.enumLiteral.name»'«element.enumLiteral.name»'«»'''
		}
	}

	def String keywordToString(Keyword element) {
		// TODO handle escaped values like '\n'
		val builder = new StringBuilder
		val node = NodeModelUtils.getNode(element)
		if (node !== null) {
			builder.append(NodeModelUtils.getTokenText(node))
		} else {
			builder.append("'")
			builder.append(element.value)
			builder.append("'")
		}
		if (element.cardinality !== null)
			builder.append(element.cardinality)
		return builder.toString
	}
}
