package io.typefox.xtext2langium

import com.google.common.collect.LinkedHashMultimap
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EDataType
import org.eclipse.emf.ecore.EcorePackage
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend2.lib.StringConcatenation
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.ReferencedMetamodel
import org.eclipse.xtext.TypeRef

@Data
class TransformationContext {
	Grammar grammar
	StringConcatenation out
	boolean generateEcoreTypes

	val interfaces = LinkedHashMultimap.<URI, EClass>create
	val types = LinkedHashMultimap.<URI, EDataType>create

	def void addTypeIfReferenced(TypeRef ref) {
		if (ref.metamodel instanceof ReferencedMetamodel)
			doAddType(ref.classifier)
	}

	def usedMetamodels() {
		return if(!interfaces.isEmpty) interfaces.keySet else types.keySet
	}

	protected def void doAddType(EClassifier classifier) {
		if (!generateEcoreTypes && classifier.EPackage.nsURI == EcorePackage.eINSTANCE.nsURI) {
			// don't generate ecore types
			return;
		}
		if (classifier instanceof EClass) {
			if (interfaces.containsValue(classifier))
				return;
			interfaces.put(classifier.EPackage.eResource.URI, classifier)
			classifier.ESuperTypes.forEach [ type |
				doAddType(type)
			]
			classifier.EReferences.forEach [ ref |
				doAddType(ref.EReferenceType)
			]
			classifier.EAttributes.forEach [ attr |
				doAddType(attr.EType)
			]
		} else if (classifier instanceof EDataType) {
			types.put(classifier.EPackage.eResource.URI, classifier)
		} else {
			println('''Unsupported classifier: «classifier.name»''')
		}
	}

}
