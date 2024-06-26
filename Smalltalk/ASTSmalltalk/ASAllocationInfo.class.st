"
I know how to generate memory objects.

I parallel what is done by the AlocationInfo struct in heap.zig
"
Class {
	#name : 'ASAllocationInfo',
	#superclass : 'Object',
	#instVars : [
		'footerLength',
		'extra',
		'instVars',
		'format'
	],
	#classVars : [
		'AgeStatic',
		'HashCounter'
	],
	#pools : [
		'ASImage'
	],
	#category : 'ASTSmalltalk-Image',
	#package : 'ASTSmalltalk',
	#tag : 'Image'
}

{ #category : 'adding' }
ASAllocationInfo class >> headerIVars: iVars indexed: nElements element: element weak: makeWeak [

	nElements ifNotNil: [
		| arraySize |
		arraySize := nElements * (element ifNil: [ 8 ]) + 7 // 8.
		makeWeak ifTrue: [
			iVars + arraySize + 3 > MaxHeaderLength ifTrue: [
				^ self new
					  format: ExternalWeakWithPointers;
					  instVars: iVars;
					  footerLength: 3 ].
			^ self new
				  format: IndexedWeakWithPointers;
				  instVars: iVars;
				  extra: arraySize;
				  footerLength: 3 ].
		iVars == 0 ifTrue: [
			(nElements == 0 or: [ element = 1 and: [ nElements < 110 ] ])
				ifTrue: [
					^ self new
						  format: nElements;
						  extra: arraySize ].
			element ifNil: [
				nElements <= MaxHeaderLength ifTrue: [
					^ self new
						  format: DirectIndexed;
						  extra: arraySize ] ] ].
		iVars + arraySize > (MaxHeaderLength - 2) ifTrue: [
			^ self new
				  format: (element = Object
						   ifTrue: [ External ]
						   ifFalse: [ ExternalNonObject ]);
				  instVars: iVars;
				  footerLength: 2 ].
		^ self new
			  format: (element = Object
					   ifTrue: [ Indexed ]
					   ifFalse: [ IndexedNonObject ]);
			  instVars: iVars;
			  extra: arraySize;
			  footerLength: 2 ].
	^ self new
		  format: NotIndexable;
		  instVars: iVars
]

{ #category : 'initialization' }
ASAllocationInfo class >> initialize [

	AgeStatic := 7.
	self reset
]

{ #category : 'initialization' }
ASAllocationInfo class >> reset [

	HashCounter := 0
]

{ #category : 'accessing' }
ASAllocationInfo >> extra: anObject [

	extra := anObject
]

{ #category : 'accessing' }
ASAllocationInfo >> footerLength: anObject [

	footerLength := anObject
]

{ #category : 'accessing' }
ASAllocationInfo >> format: fmt [ 

	format := fmt
]

{ #category : 'accessing' }
ASAllocationInfo >> header: classNumber [

	| length |
	length := instVars + extra + footerLength.
	length < MaxHeaderLength ifFalse: [ self error: 'header too big' ].
	HashCounter := HashCounter + 1.
	^ length << 4 + AgeStatic << 8 + format << 24 + HashCounter << 16
	  + classNumber
]

{ #category : 'initialization' }
ASAllocationInfo >> initialize [

	super initialize.
	instVars := 0.
	footerLength := 0.
	extra := 0
]

{ #category : 'accessing' }
ASAllocationInfo >> instVars: n [

	instVars := n
]

{ #category : 'accessing' }
ASAllocationInfo >> put: anObject into: anImage [

	| address class |
	class := anImage class: anObject class.
	address := anImage putRawInt: (self header: class).
	1 to: instVars do: [ :n | (anObject instVarAt: n) astImageObject: anImage ].
	1 to: extra do: [ :n | (anObject at: n) astImageObject: anImage ].
	^ anImage pointer: address class: class
]
