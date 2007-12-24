--
-- PostgreSQL database dump
--

SET client_encoding = 'LATIN9';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: lang; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE lang (
    "desc" text,
    lang_id integer NOT NULL
);


ALTER TABLE public.lang OWNER TO postgres;

--
-- Name: lang_lang_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE lang_lang_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.lang_lang_id_seq OWNER TO postgres;

--
-- Name: lang_lang_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE lang_lang_id_seq OWNED BY lang.lang_id;


--
-- Name: lang_lang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('lang_lang_id_seq', 420, true);


--
-- Name: paste; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE paste (
    id integer NOT NULL,
    poster character varying,
    posted timestamp without time zone,
    code character varying,
    lang_id bigint,
    expires bigint,
    sha1 text
);


ALTER TABLE public.paste OWNER TO postgres;

--
-- Name: paste_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE paste_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.paste_id_seq OWNER TO postgres;

--
-- Name: paste_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE paste_id_seq OWNED BY paste.id;


--
-- Name: paste_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('paste_id_seq', 21, true);


--
-- Name: lang_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE lang ALTER COLUMN lang_id SET DEFAULT nextval('lang_lang_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE paste ALTER COLUMN id SET DEFAULT nextval('paste_id_seq'::regclass);


--
-- Data for Name: lang; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY lang ("desc", lang_id) FROM stdin;
a65	3
aap	4
abaqus	5
abc	6
abel	7
acedb	8
ada	9
aflex	10
ahdl	11
alsaconf	12
amiga	13
aml	14
ampl	15
antlr	16
ant	17
apachestyle	18
apache	19
arch	20
art	21
asm68k	22
asmh8300	23
asm	24
asn	25
aspperl	26
aspvbs	27
asterisk	28
atlas	29
automake	30
ave	31
awk	32
ayacc	33
baan	34
basic	35
bc	36
bdf	37
bib	38
bindzone	39
blank	40
btm	41
b	42
calendar	43
catalog	44
cdl	45
cfg	46
cf	47
changelog	48
change	49
chaskell	50
cheetah	51
chill	52
ch	53
clean	54
clipper	55
cl	56
cobol	57
colortest	58
config	59
conf	60
cpp	61
crm	62
crontab	63
csc	64
csh	65
csp	66
css	67
cs	68
cterm	69
ctrlh	70
cuplsim	71
cupl	72
c	73
cvsrc	74
cvs	75
cweb	76
cynlib	77
cynpp	78
dcd	79
dcl	80
debchangelog	81
debcontrol	82
debsources	83
def	84
desc	85
desktop	86
diff	87
dircolors	88
diva	89
dns	90
docbksgml	91
docbk	92
docbkxml	93
dosbatch	94
dosini	95
dot	96
dracula	97
dsl	98
dtd	99
dtml	100
d	101
dylanintr	102
dylanlid	103
dylan	104
ecd	105
edif	106
eiffel	107
elf	108
elinks	109
elmfilt	110
erlang	111
eruby	112
esmtprc	113
esqlc	114
esterel	115
eterm	116
exim	117
expect	118
exports	119
fasm	120
fdcc	121
fetchmail	122
fgl	123
focexec	124
form	125
forth	126
fortran	127
foxpro	128
fstab	129
fvwm2m4	130
fvwm	131
gdb	132
gdmo	133
gedcom	134
gkrellmrc	135
gnuplot	136
gpg	137
gp	138
grads	139
groff	140
grub	141
gsp	142
gtkrc	143
haskell	144
hb	145
help	146
hercules	147
hex	148
hitest	149
hog	150
htmlcheetah	151
htmlm4	152
htmlos	153
html	154
ia64	155
icemenu	156
icon	157
idlang	158
idl	159
indent	160
inform	161
inittab	162
ipfilter	163
ishd	164
iss	165
ist	166
jal	167
jam	168
jargon	169
javacc	170
javascript	171
java	172
jess	173
jgraph	174
jproperties	175
jsp	176
kix	177
kscript	178
kwt	179
lace	180
latte	181
ldif	182
lex	183
lftp	184
lhaskell	185
libao	186
lifelines	187
lilo	188
lisp	189
lite	190
logtalk	191
lotos	192
lout	193
lpc	194
lprolog	195
lscript	196
lss	197
lua	198
lynx	199
m4	200
mailcap	201
mail	202
make	203
manual	204
man	205
maple	206
masm	207
mason	208
master	209
matlab	210
mel	211
mf	212
mgp	213
mib	214
mma	215
mmix	216
modconf	217
model	218
modsim3	219
modula2	220
modula3	221
monk	222
moo	223
mplayerconf	224
mp	225
msidl	226
msql	227
mush	228
muttrc	229
mysql	230
named	231
nasm	232
nastran	233
natural	234
ncf	235
netrc	236
nosyntax	237
nqc	238
nroff	239
nsis	240
objcpp	241
objc	242
ocaml	243
occam	244
omnimark	245
openroad	246
opl	247
ora	248
papp	249
pascal	250
pcap	251
pccts	252
perl	253
pfmain	254
pf	255
php	256
phtml	257
pic	258
pike	259
pilrc	260
pine	261
pinfo	262
plm	263
plp	264
plsql	265
pod	266
postscr	267
po	268
povini	269
pov	270
ppd	271
ppwiz	272
prescribe	273
procmail	274
progress	275
prolog	276
psf	277
ptcap	278
purifylog	279
pyrex	280
python	281
qf	282
quake	283
radiance	284
ratpoison	285
rcslog	286
rcs	287
rc	288
readline	289
README.txt	290
rebol	291
registry	292
remind	293
resolv	294
rexx	295
rib	296
rnc	297
robots	298
rpcgen	299
rpl	300
rst	301
rtf	302
ruby	303
r	304
samba	305
sas	306
sather	307
scheme	308
scilab	309
screen	310
sdl	311
sed	312
sendpr	313
sgmldecl	314
sgmllnx	315
sgml	316
sh	317
sicad	318
simula	319
sindacmp	320
sindaout	321
sinda	322
skill	323
slang	324
slice	325
slrnrc	326
slrnsc	327
sl	328
smarty	329
smil	330
smith	331
sml	332
sm	333
snnsnet	334
snnspat	335
snnsres	336
snobol4	337
specman	338
spec	339
spice	340
splint	341
spup	342
spyce	343
sqlforms	344
sqlj	345
sql	346
sqr	347
squid	348
sshconfig	349
sshdconfig	350
stp	351
strace	352
st	353
sudoers	354
svn	355
syncolor	356
synload	357
syntax	358
tads	359
tags	360
takcmp	361
takout	362
tak	363
tasm	364
tcl	365
tcsh	366
terminfo	367
texinfo	368
texmf	369
tex	370
tf	371
tidy	372
tilde	373
tli	374
tpp	375
trasys	376
tsalt	377
tsscl	378
tssgm	379
tssop	380
uc	381
uil	382
valgrind	383
vb	384
verilogams	385
verilog	386
vgrindefs	387
vhdl	388
viminfo	389
vim	390
virata	391
vmasm	392
vrml	393
vsejcl	394
wdiff	395
webmacro	396
web	397
wget	398
whitespace	399
winbatch	400
wml	401
wsh	402
wvdial	403
xdefaults	404
xf86conf	405
xhtml	406
xkb	407
xmath	408
xml	409
xmodmap	410
xpm2	411
xpm	412
xsd	413
xslt	414
xs	415
xxd	416
yacc	417
yaml	418
z8a	419
zsh	420
\.


--
-- Data for Name: paste; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY paste (id, poster, posted, code, lang_id, expires, sha1) FROM stdin;
\.


--
-- Name: lang_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lang
    ADD CONSTRAINT lang_pkey PRIMARY KEY (lang_id);


--
-- Name: paste_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY paste
    ADD CONSTRAINT paste_pkey PRIMARY KEY (id);


--
-- Name: id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX id_index ON paste USING btree (id);


--
-- Name: index_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX index_id ON lang USING btree (lang_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

