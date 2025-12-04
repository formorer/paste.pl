INSERT INTO lang(lang_id, "desc") VALUES
(-1, 'text'),
(1, 'perl'),
(2, 'python'),
(3, 'bash'),
(4, 'c'),
(5, 'cpp'),
(6, 'json')
ON CONFLICT DO NOTHING;
