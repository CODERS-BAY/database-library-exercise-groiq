
print('set foreign_key_checks = 0;')

tables = '''
author
authorship
book
book_copy
counter_event
customer
employee
journal
journal_article
journal_issue
keyword
kwd_synonym
loan
loan_process
publisher
reservation
shelf
subject_area
text_kwd
textx
'''.split('\n')

for table in tables:
    if not table:
        continue
    table = table.strip()
    print(f'truncate table {table};')

print('set foreign_key_checks = 1;')

