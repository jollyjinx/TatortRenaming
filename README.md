This is a renaming script for German TV-Series, Tatort, no need to write docu in something other then german.

Tatort Renaming
===============

Dies ist ein simples Script, das vom Fernsehen aufgenommene Tatorte korrekt benennt, d.h. Erstaustrahlung-Kommissar-Episodenname

Beispiel:

	Aus: Tatort - 840, Hanglage mit Aussicht.m4v
	wird: 2012.08.26-Flueckiger-Hanglage mit Aussicht.m4v


Benutzung
---------

	./tatort.perl "Tatort - 840, Hanglage mit Aussicht.m4v"


Wie es funktioniert
-------------------

Das Script lädt von der tatort Website die Kommissare und Episoden aller Tatorte. Dann werden diese Daten normalisiert und mit dem normalisierten Namen der Eingabe verglichen.
Ich benutze EyeTV zum Aufzeichnen der Episoden, daher funktionert das wunderbar mit dem korrigieren. 

