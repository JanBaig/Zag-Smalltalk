"
I am the baseline for ASTSmalltalk aka ZagSmalltalk
"
Class {
	#name : 'BaselineOfZagSmalltalk',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfZagSmalltalk',
	#package : 'BaselineOfZagSmalltalk'
}

{ #category : 'baselines' }
BaselineOfZagSmalltalk >> baseline: spec [

	<baseline>
	spec for: #common do: [ "Packages"
		spec
			package: 'Zag-Core';
			package: 'Zag-Core-Tests'
			with: [ spec requires: #( 'Zag-Core' ) ];
			package: 'Zag-Smalltalk-LLVM'
			with: [ spec requires: #( 'Zag-Core' ) ];
			package: 'Zag-Smalltalk-LLVM-Tests'
			with: [
				spec requires: #( 'Zag-Smalltalk-LLVM' 'Zag-Core-Tests' ) ];
			package: 'Benchmarks' with: [ spec requires: #( 'Zag-Core' ) ];
			package: 'Zag-LLVM' with: [ spec requires: #( 'Zag-Core' ) ];
			package: 'Zag-LLVM-Tests' with: [ spec requires: #( 'Zag-LLVM' ) ];
			package: 'Zag-Exporter'
			with: [ spec requires: #( 'Zag-Core' ) ];
			package: 'Zag-Exporter-Tests'
			with: [ spec requires: #( 'Zag-Exporter' 'Zag-Core-Tests' ) ];
			package: 'Zag-Library' ]
]

{ #category : 'accessing' }
BaselineOfZagSmalltalk >> projectClass [
	^ MetacelloCypressBaselineProject
]