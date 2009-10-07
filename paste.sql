--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET search_path = public, pg_catalog;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: www-data
--

CREATE SEQUENCE comments_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.comments_id_seq OWNER TO "www-data";

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: www-data; Tablespace: 
--

CREATE TABLE comments (
    id integer DEFAULT nextval('comments_id_seq'::regclass) NOT NULL,
    text character varying,
    name character varying,
    date timestamp without time zone,
    paste_id integer
);


ALTER TABLE public.comments OWNER TO "www-data";

--
-- Name: lang; Type: TABLE; Schema: public; Owner: www-data; Tablespace: 
--

CREATE TABLE lang (
    "desc" text,
    lang_id integer NOT NULL
);


ALTER TABLE public.lang OWNER TO "www-data";

--
-- Name: lang_lang_id_seq; Type: SEQUENCE; Schema: public; Owner: www-data
--

CREATE SEQUENCE lang_lang_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.lang_lang_id_seq OWNER TO "www-data";

--
-- Name: lang_lang_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: www-data
--

ALTER SEQUENCE lang_lang_id_seq OWNED BY lang.lang_id;


--
-- Name: paste; Type: TABLE; Schema: public; Owner: www-data; Tablespace: 
--

CREATE TABLE paste (
    id integer NOT NULL,
    poster character varying,
    posted timestamp without time zone,
    code character varying,
    lang_id bigint,
    expires bigint,
    sha1 text,
    sessionid text,
    hidden boolean
);


ALTER TABLE public.paste OWNER TO "www-data";

--
-- Name: paste_id_seq; Type: SEQUENCE; Schema: public; Owner: www-data
--

CREATE SEQUENCE paste_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.paste_id_seq OWNER TO "www-data";

--
-- Name: paste_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: www-data
--

ALTER SEQUENCE paste_id_seq OWNED BY paste.id;


--
-- Name: lang_id; Type: DEFAULT; Schema: public; Owner: www-data
--

ALTER TABLE lang ALTER COLUMN lang_id SET DEFAULT nextval('lang_lang_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: www-data
--

ALTER TABLE paste ALTER COLUMN id SET DEFAULT nextval('paste_id_seq'::regclass);


--
-- Name: lang_pkey; Type: CONSTRAINT; Schema: public; Owner: www-data; Tablespace: 
--

ALTER TABLE ONLY lang
    ADD CONSTRAINT lang_pkey PRIMARY KEY (lang_id);


--
-- Name: paste_pkey; Type: CONSTRAINT; Schema: public; Owner: www-data; Tablespace: 
--

ALTER TABLE ONLY paste
    ADD CONSTRAINT paste_pkey PRIMARY KEY (id);


--
-- Name: id_index; Type: INDEX; Schema: public; Owner: www-data; Tablespace: 
--

CREATE UNIQUE INDEX id_index ON paste USING btree (id);


--
-- Name: index_id; Type: INDEX; Schema: public; Owner: www-data; Tablespace: 
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

--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: lang; Type: TABLE; Schema: public; Owner: www-data; Tablespace: 
--

CREATE TABLE lang (
    "desc" text,
    lang_id integer NOT NULL
);


ALTER TABLE public.lang OWNER TO "www-data";

--
-- Name: lang_lang_id_seq; Type: SEQUENCE; Schema: public; Owner: www-data
--

CREATE SEQUENCE lang_lang_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.lang_lang_id_seq OWNER TO "www-data";

--
-- Name: lang_lang_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: www-data
--

ALTER SEQUENCE lang_lang_id_seq OWNED BY lang.lang_id;


--
-- Name: lang_lang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: www-data
--

SELECT pg_catalog.setval('lang_lang_id_seq', 901, true);


--
-- Name: lang_id; Type: DEFAULT; Schema: public; Owner: www-data
--

ALTER TABLE lang ALTER COLUMN lang_id SET DEFAULT nextval('lang_lang_id_seq'::regclass);


--
-- Data for Name: lang; Type: TABLE DATA; Schema: public; Owner: www-data
--

INSERT INTO lang VALUES ('sourceslist', 742);
INSERT INTO lang VALUES ('delphi', 743);
INSERT INTO lang VALUES ('js+mako', 744);
INSERT INTO lang VALUES ('brainfuck', 745);
INSERT INTO lang VALUES ('html+cheetah', 746);
INSERT INTO lang VALUES ('html+evoque', 747);
INSERT INTO lang VALUES ('numpy', 748);
INSERT INTO lang VALUES ('bash', 749);
INSERT INTO lang VALUES ('html+django', 750);
INSERT INTO lang VALUES ('css+php', 751);
INSERT INTO lang VALUES ('vim', 752);
INSERT INTO lang VALUES ('css+genshitext', 753);
INSERT INTO lang VALUES ('css+myghty', 754);
INSERT INTO lang VALUES ('ragel', 755);
INSERT INTO lang VALUES ('smarty', 756);
INSERT INTO lang VALUES ('xml+evoque', 757);
INSERT INTO lang VALUES ('redcode', 758);
INSERT INTO lang VALUES ('django', 759);
INSERT INTO lang VALUES ('apacheconf', 760);
INSERT INTO lang VALUES ('scala', 761);
INSERT INTO lang VALUES ('lighty', 762);
INSERT INTO lang VALUES ('java', 763);
INSERT INTO lang VALUES ('js+genshitext', 764);
INSERT INTO lang VALUES ('scheme', 765);
INSERT INTO lang VALUES ('rhtml', 766);
INSERT INTO lang VALUES ('ragel-java', 767);
INSERT INTO lang VALUES ('dpatch', 768);
INSERT INTO lang VALUES ('ragel-d', 769);
INSERT INTO lang VALUES ('html+myghty', 770);
INSERT INTO lang VALUES ('rbcon', 771);
INSERT INTO lang VALUES ('css', 772);
INSERT INTO lang VALUES ('js+smarty', 773);
INSERT INTO lang VALUES ('d-objdump', 774);
INSERT INTO lang VALUES ('xml+php', 775);
INSERT INTO lang VALUES ('css+erb', 776);
INSERT INTO lang VALUES ('fortran', 777);
INSERT INTO lang VALUES ('gnuplot', 778);
INSERT INTO lang VALUES ('mysql', 779);
INSERT INTO lang VALUES ('rebol', 780);
INSERT INTO lang VALUES ('cpp', 781);
INSERT INTO lang VALUES ('pot', 782);
INSERT INTO lang VALUES ('evoque', 783);
INSERT INTO lang VALUES ('xml+smarty', 784);
INSERT INTO lang VALUES ('dylan', 785);
INSERT INTO lang VALUES ('trac-wiki', 786);
INSERT INTO lang VALUES ('matlab', 787);
INSERT INTO lang VALUES ('c', 788);
INSERT INTO lang VALUES ('html', 789);
INSERT INTO lang VALUES ('genshi', 790);
INSERT INTO lang VALUES ('rst', 791);
INSERT INTO lang VALUES ('mako', 792);
INSERT INTO lang VALUES ('irc', 793);
INSERT INTO lang VALUES ('prolog', 794);
INSERT INTO lang VALUES ('python', 795);
INSERT INTO lang VALUES ('css+django', 796);
INSERT INTO lang VALUES ('smalltalk', 797);
INSERT INTO lang VALUES ('js+myghty', 798);
INSERT INTO lang VALUES ('yaml', 799);
INSERT INTO lang VALUES ('antlr-as', 800);
INSERT INTO lang VALUES ('xml+mako', 801);
INSERT INTO lang VALUES ('xslt', 802);
INSERT INTO lang VALUES ('splus', 803);
INSERT INTO lang VALUES ('sqlite3', 804);
INSERT INTO lang VALUES ('boo', 805);
INSERT INTO lang VALUES ('ocaml', 806);
INSERT INTO lang VALUES ('as', 807);
INSERT INTO lang VALUES ('vb.net', 808);
INSERT INTO lang VALUES ('squidconf', 809);
INSERT INTO lang VALUES ('d', 810);
INSERT INTO lang VALUES ('logtalk', 811);
INSERT INTO lang VALUES ('erb', 812);
INSERT INTO lang VALUES ('bbcode', 813);
INSERT INTO lang VALUES ('rb', 814);
INSERT INTO lang VALUES ('py3tb', 815);
INSERT INTO lang VALUES ('mupad', 816);
INSERT INTO lang VALUES ('xml+erb', 817);
INSERT INTO lang VALUES ('control', 818);
INSERT INTO lang VALUES ('ragel-cpp', 819);
INSERT INTO lang VALUES ('befunge', 820);
INSERT INTO lang VALUES ('c-objdump', 821);
INSERT INTO lang VALUES ('jsp', 822);
INSERT INTO lang VALUES ('abap', 823);
INSERT INTO lang VALUES ('js+cheetah', 824);
INSERT INTO lang VALUES ('html+mako', 825);
INSERT INTO lang VALUES ('diff', 826);
INSERT INTO lang VALUES ('matlabsession', 827);
INSERT INTO lang VALUES ('objdump', 828);
INSERT INTO lang VALUES ('css+mako', 829);
INSERT INTO lang VALUES ('html+php', 830);
INSERT INTO lang VALUES ('make', 831);
INSERT INTO lang VALUES ('io', 832);
INSERT INTO lang VALUES ('vala', 833);
INSERT INTO lang VALUES ('haskell', 834);
INSERT INTO lang VALUES ('lua', 835);
INSERT INTO lang VALUES ('pov', 836);
INSERT INTO lang VALUES ('antlr-java', 837);
INSERT INTO lang VALUES ('antlr-objc', 838);
INSERT INTO lang VALUES ('js+erb', 839);
INSERT INTO lang VALUES ('xml', 840);
INSERT INTO lang VALUES ('basemake', 841);
INSERT INTO lang VALUES ('antlr-python', 842);
INSERT INTO lang VALUES ('glsl', 843);
INSERT INTO lang VALUES ('genshitext', 844);
INSERT INTO lang VALUES ('python3', 845);
INSERT INTO lang VALUES ('gas', 846);
INSERT INTO lang VALUES ('bat', 847);
INSERT INTO lang VALUES ('pycon', 848);
INSERT INTO lang VALUES ('antlr', 849);
INSERT INTO lang VALUES ('xml+cheetah', 850);
INSERT INTO lang VALUES ('js+django', 851);
INSERT INTO lang VALUES ('minid', 852);
INSERT INTO lang VALUES ('cython', 853);
INSERT INTO lang VALUES ('ragel-c', 854);
INSERT INTO lang VALUES ('erlang', 855);
INSERT INTO lang VALUES ('erl', 856);
INSERT INTO lang VALUES ('aspx-vb', 857);
INSERT INTO lang VALUES ('aspx-cs', 858);
INSERT INTO lang VALUES ('groff', 859);
INSERT INTO lang VALUES ('clojure', 860);
INSERT INTO lang VALUES ('modelica', 861);
INSERT INTO lang VALUES ('antlr-perl', 862);
INSERT INTO lang VALUES ('ragel-ruby', 863);
INSERT INTO lang VALUES ('myghty', 864);
INSERT INTO lang VALUES ('html+genshi', 865);
INSERT INTO lang VALUES ('tcl', 866);
INSERT INTO lang VALUES ('perl', 867);
INSERT INTO lang VALUES ('ini', 868);
INSERT INTO lang VALUES ('moocode', 869);
INSERT INTO lang VALUES ('newspeak', 870);
INSERT INTO lang VALUES ('console', 871);
INSERT INTO lang VALUES ('cpp-objdump', 872);
INSERT INTO lang VALUES ('raw', 873);
INSERT INTO lang VALUES ('tcsh', 874);
INSERT INTO lang VALUES ('csharp', 875);
INSERT INTO lang VALUES ('tex', 876);
INSERT INTO lang VALUES ('css+smarty', 877);
INSERT INTO lang VALUES ('text', 878);
INSERT INTO lang VALUES ('antlr-csharp', 879);
INSERT INTO lang VALUES ('cheetah', 880);
INSERT INTO lang VALUES ('llvm', 881);
INSERT INTO lang VALUES ('nginx', 882);
INSERT INTO lang VALUES ('applescript', 883);
INSERT INTO lang VALUES ('html+smarty', 884);
INSERT INTO lang VALUES ('objective-c', 885);
INSERT INTO lang VALUES ('js', 886);
INSERT INTO lang VALUES ('common-lisp', 887);
INSERT INTO lang VALUES ('ragel-em', 888);
INSERT INTO lang VALUES ('as3', 889);
INSERT INTO lang VALUES ('lhs', 890);
INSERT INTO lang VALUES ('pytb', 891);
INSERT INTO lang VALUES ('php', 892);
INSERT INTO lang VALUES ('antlr-cpp', 893);
INSERT INTO lang VALUES ('js+php', 894);
INSERT INTO lang VALUES ('sql', 895);
INSERT INTO lang VALUES ('ragel-objc', 896);
INSERT INTO lang VALUES ('xml+django', 897);
INSERT INTO lang VALUES ('mxml', 898);
INSERT INTO lang VALUES ('nasm', 899);
INSERT INTO lang VALUES ('antlr-ruby', 900);
INSERT INTO lang VALUES ('xml+myghty', 901);


--
-- Name: lang_pkey; Type: CONSTRAINT; Schema: public; Owner: www-data; Tablespace: 
--

ALTER TABLE ONLY lang
    ADD CONSTRAINT lang_pkey PRIMARY KEY (lang_id);


--
-- Name: index_id; Type: INDEX; Schema: public; Owner: www-data; Tablespace: 
--

CREATE UNIQUE INDEX index_id ON lang USING btree (lang_id);


--
-- PostgreSQL database dump complete
--

