Extension { #name : 'Object' }

{ #category : '*Zag-Core' }
Object >> asASIdentifier [
	(#('true' 'false' 'nil' 'thisContext') includes: self) ifTrue: [ ^ self asASSpecial ].
	(#('self' 'super') includes: self) ifTrue: [ ^ self asASSelf ].
	'|' = self ifTrue: [ ^ self asASSyntax ].
	^ ASIdentifier with: self asString
]

{ #category : '*Zag-Core' }
Object >> asASLiteral [
	^ ASLiteralToken new value: self
]

{ #category : '*Zag-Core' }
Object >> asASSelf [
	^ ASSelfToken new value: self
]

{ #category : '*Zag-Core' }
Object >> asASSpecial [
	^ ASSpecial new value: self
]

{ #category : '*Zag-Core' }
Object >> asASString [
	^ ASString new value: self
]

{ #category : '*Zag-Core' }
Object >> asASSymbol [
	^ ASSymbol new value: self asSymbol
]

{ #category : '*Zag-Core' }
Object >> asASSyntax [
	^ ASSyntax with: self
]

{ #category : '*Zag-Core' }
Object class >> astClass [

	^ (name beginsWith: 'AST')
		ifTrue: [ self ]
		ifFalse: [ Smalltalk at: ('AST' , name) asSymbol ifAbsent: [ self ] ]
]

{ #category : '*Zag-Core' }
Object >> astFields [
	| nVars fields |
	nVars := self class instSize.
	fields := Array new: nVars.
	1 to: nVars do: [ :i | fields at: i put: (self instVarAt: i) ].

]

{ #category : '*Zag-Core' }
Object >> astFormat [
	^ 1
]

{ #category : '*Zag-Core' }
Object >> astImageObject: anASImage [

	^ anASImage objectObject: self
]

{ #category : '*Zag-Core' }
Object >> children [
"return and empty list as the default children of any element"
 ^  {  }
]

{ #category : '*Zag-Core' }
Object >> contents [

	^ String streamContents: [ :stream | self inspectZagASTOn: stream ]
]

{ #category : '*Zag-Core' }
Object >> inspectZagASTOn: aStream [
	aStream
		nextPutAll: self class name.
]

{ #category : '*Zag-Core' }
Object >> isFlowSource [

	^ false
]

{ #category : '*Zag-Core' }
Object >> zigCompileObject: aGenerator [

	| slots label |
	slots := (self isArray
		          ifTrue: [ self ]
		          ifFalse: [ self class allSlots ]) size.
	
	((1 to: slots) collect: [ :n |
		 | x |
		 x := self instVarAt: n.
		 x := x -> (x zigCompileObjectReference: aGenerator) ]) do: [ :each |
		each value
			ifNil: [ each key zigCompileObject: aGenerator ]
			ifNotNil: [ aGenerator labelRef: each value ].
		aGenerator comma ].
	label := aGenerator nextLabel.
	aGenerator putClass: self class name.
	^ label
]

{ #category : '*Zag-Core' }
Object >> zigCompileObjectReference: aGenerator [

	(aGenerator lookupObject: self) ifNotNil: [ :v | ^ v ].
	^ self zigCompileObject: aGenerator
]