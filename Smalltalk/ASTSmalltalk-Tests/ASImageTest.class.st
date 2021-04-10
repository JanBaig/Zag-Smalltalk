Class {
	#name : #ASImageTest,
	#superclass : #TestCase,
	#instVars : [
		'imageWriter',
		'minImageSize'
	],
	#category : #'ASTSmalltalk-Tests-Tests'
}

{ #category : #tests }
ASImageTest >> array: aBlock [
	^ (self stream: aBlock) asArray
]

{ #category : #tests }
ASImageTest >> image [

	^ ByteArray streamContents: [ :s | imageWriter writeImageOn: s ]
]

{ #category : #running }
ASImageTest >> setUp [
	super setUp.
	imageWriter := ASImage new.
	minImageSize := 364.

]

{ #category : #tests }
ASImageTest >> stream: aBlock [
	^ ByteArray streamContents: aBlock
]

{ #category : #tests }
ASImageTest >> testAdditions [
	| a1 a1o |
	self assert: (imageWriter imageObject: 42) equals: 16r7ff8000000000155.
	self assert: (imageWriter imageObject: 1) equals: 16r7ff800000000000d.
	self assert: (imageWriter imageObject: true) equals: 16r7ff800000000000c.
	self assert: (imageWriter imageObject: false) equals: 16r7ff8000000000003.
	self assert: (imageWriter imageObject: nil) equals: 16r7ff800000000000a.
	self assert: (imageWriter imageObject: $A) equals: 16r7ff800000000020f.
	self assert: (imageWriter imageObject: #foo) equals: 16r7ff800000000009e.
	self assert: (imageWriter imageObject: #value:) equals: 16r7ff800000100000e.
	self assert: (imageWriter imageObject: #value:value:) equals: 16r7ff8000002000016.
	self assert: (imageWriter imageObject: 42.0) equals: 16r4045000000000000.
	self assert: imageWriter offset equals: 16.
	a1 := #(1 true nil).
	a1o := imageWriter imageObject: a1.
	self assert: a1o equals: 16r7ff8001000000010.
	self assert: imageWriter offset equals: 48.
	self assert: (imageWriter imageObject: a1) equals: a1o.
	self assert: imageWriter offset equals: 48.
	self assert: (self image at64: 24) equals: 16r7ff800000000000d.
	self assert: (self image at64: 32) equals: 16r7ff800000000000c.
	self assert: (self image at64: 40) equals: 16r7ff800000000000a.


]

{ #category : #tests }
ASImageTest >> testEmptyImage [
	self assert: self image size equals: minImageSize
]

{ #category : #tests }
ASImageTest >> testHeader [
	self assert: (imageWriter header: #(isVariable)) equals: 16r80000000000.

]

{ #category : #tests }
ASImageTest >> testWriteRawOn [
	self assert: (self array: [: s | 1 writeRawOn: s ]) equals: #(1 0 0 0 0 0 0 0).
	self assert: (self array: [: s | -1 writeRawOn: s ]) equals: #(255 255 255 255 255 255 255 255).
	self assert: (self array: [: s | 256 writeRawOn: s ]) equals: #(0 1 0 0 0 0 0 0).
	self assert: (self array: [: s | -256 writeRawOn: s ]) equals: #(0 255 255 255 255 255 255 255).

]