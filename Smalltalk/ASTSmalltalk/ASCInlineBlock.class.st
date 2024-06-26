"
for inlining
"
Class {
	#name : 'ASCInlineBlock',
	#superclass : 'ASCBasicBlock',
	#category : 'ASTSmalltalk-CodeGen',
	#package : 'ASTSmalltalk',
	#tag : 'CodeGen'
}

{ #category : 'adding' }
ASCInlineBlock >> addSourceBlock: aBasicBlock [

	sourceBlocks
		add: aBasicBlock
		andIfNewDo: [
		sourceElements := stack := aBasicBlock copyOfStackFor: self ]
		orIfExistedDo: [
			sourceElements do: [ :stackElement |
				stackElement mergeWith: aBasicBlock ] ]
]

{ #category : 'data flow instructions' }
ASCInlineBlock >> checkForCalls [

	(sourceBlocks anySatisfy: #endsWithCall) ifFalse: [ ^ self ].
	self primitiveChangeClassTo: ASCReturnBlock basicNew.
	stack makeStackTheSource
]

{ #category : 'data flow instructions' }
ASCInlineBlock >> classForLocals [

	^ ASFlowPhi
]

{ #category : 'data flow instructions' }
ASCInlineBlock >> classForTemporaries [

	^ ASFlowPhi
]

{ #category : 'initialization' }
ASCInlineBlock >> label [

	^ label ifNil: [ label := self nextSequence asString ]
]

{ #category : 'initialization' }
ASCInlineBlock >> llvmLabel [

	^ self label
]

{ #category : 'printing' }
ASCInlineBlock >> locals: locals parameters: arguments [

	self nameStack: arguments.
	locals do: [ :each | self initLocalNamed: each ].
	maxDepth := 0
]

{ #category : 'adding' }
ASCInlineBlock >> nameStack: parameterNamesLeftToRight [

	| names |
	names := OrderedCollection with: #self.
	names addAll: parameterNamesLeftToRight.
	stack := stack nameStack: names offset: 0 forBlock: self
]

{ #category : 'data flow instructions' }
ASCInlineBlock >> namedBlock [

	^ sourceBlocks anyOne namedBlock
]

{ #category : 'successor sequences' }
ASCInlineBlock >> nextSequence [

	^self  methodBlock nextSequence
]

{ #category : 'writing' }
ASCInlineBlock >> outputTo: output [

	output outputInlineBlockStart: self.
	^ self outputRestTo: output
]

{ #category : 'printing' }
ASCInlineBlock >> printOn: aStream [

	aStream nextPutAll: '>>'; nextPutAll: self label
]

{ #category : 'data flow instructions' }
ASCInlineBlock >> selfElementClass [

	^ ASStackSelf
]

{ #category : 'initialization' }
ASCInlineBlock >> setStackForBlock: anASCBlock [ 
	anASCBlock scope: stack.
]

{ #category : 'printing' }
ASCInlineBlock >> updateStack: aSymbol [
	^ nil
]
