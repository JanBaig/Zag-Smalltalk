Class {
	#name : 'ASCodeTest',
	#superclass : 'TestCase',
	#instVars : [
		'file'
	],
	#category : 'Zag-Output-Tests-Tests',
	#package : 'Zag-Output-Tests',
	#tag : 'Tests'
}

{ #category : 'method' }
ASCodeTest >> astFor: aMethod [ 
	^ ASPharoCompiler new astFor: aMethod
]