import pathlib
f = pathlib.Path('d:/Projects/Mastering_Toolshop/ui/server.py')
text = f.read_text()
old = 'project_win = str(PROJECT_ROOT).replace(\"/\", \"\\\\\")'
new = 'project_win = str(PROJECT_ROOT / \"music_tracks\" / \"raw_wav_files\").replace(\"/\", \"\\\\\")'
text = text.replace(old, new)
f.write_text(text)
print('Fixed server.py')
