Class {
	#name : 'ASZigCPSBlockOutput',
	#superclass : 'ASZigCPSOutput',
	#instVars : [
		'methodGenerator',
		'block'
	],
	#category : 'Zag-Core-Output',
	#package : 'Zag-Core',
	#tag : 'Output'
}

{ #category : 'accessing' }
ASZigCPSBlockOutput >> block [
	^ methodGenerator 	block
]

{ #category : 'code generation' }
ASZigCPSBlockOutput >> codeGeneratorClass [

	^ ASCodeGeneratorBlock
]

{ #category : 'compiling' }
ASZigCPSBlockOutput >> methodGenerator [

	^ methodGenerator
]

{ #category : 'accessing' }
ASZigCPSBlockOutput >> methodGenerator: anOutput block: anInteger [

	methodGenerator := anOutput.
	block := anInteger
]

{ #category : 'accessing' }
ASZigCPSBlockOutput >> prefix [

	^ 'B'
]

{ #category : 'visiting' }
ASZigCPSBlockOutput >> visitReturnSelf [
	self nextPutAll: 'RETURNSELF';endStatement 
]
