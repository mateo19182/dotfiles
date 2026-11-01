import subprocess,tempfile,unittest
from pathlib import Path
from github_scope import repository_exclusions, exclusions as github_exclusions
from unittest.mock import patch
import github_scope

class GitScopeTest(unittest.TestCase):
    def test_only_mirrored_clean_source_is_excluded(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            def git(*args):
                return subprocess.check_output(['git','-C',folder,*args],stderr=subprocess.DEVNULL)
            git('init');git('config','user.name','Backup test');git('config','user.email','backup@example.invalid')
            (root/'unchanged.py').write_text('unchanged\n');git('add','unchanged.py')
            (root/'source.py').write_text('original\n');git('add','source.py');git('commit','-m','initial')
            git('remote','add','origin','https://github.com/example/fixture.git')
            head=git('rev-parse','HEAD').strip()
            remote=lambda path,name: head+b'\trefs/heads/main\n'
            (root/'untracked-original.txt').write_text('unique work\n')
            excluded,_=repository_exclusions(root,remote)
            self.assertIn(str(root/'source.py'),excluded)
            self.assertNotIn(str(root/'untracked-original.txt'),excluded)
            (root/'source.py').write_text('changed locally\n')
            excluded,_=repository_exclusions(root,remote)
            self.assertNotIn(str(root/'source.py'),excluded)
            self.assertIn(str(root/'unchanged.py'),excluded)
            (root/'unchanged.py').unlink()
            deletion_record={}
            repository_exclusions(root,remote,deletion_record)
            self.assertEqual(deletion_record['deleted_files'],['unchanged.py'])
            (root/'unchanged.py').write_text('unchanged\n')
            git('add','source.py');git('commit','-m','unpushed')
            self.assertEqual(repository_exclusions(root,remote)[0],[])
            (root/'final.pth').write_text('own trained model')
            git('add','final.pth');git('commit','-m','publish checkpoint')
            published=git('rev-parse','HEAD').strip()
            original_git=github_scope.git
            def local_git(path,*args):
                if args and args[0]=='ls-remote':return published+b'\trefs/heads/main\n'
                return original_git(path,*args)
            config={'github_backup_candidates':[str(root)],'selections':[{'id':'own-tfg-checkpoint-fixture','kind':'files','path':str(root/'final.pth'),'choice':'local'}]}
            with patch('github_scope.git',side_effect=local_git):
                filtered,_=github_exclusions(config,[str(root)],[])
            self.assertNotIn(str(root/'final.pth'),filtered)
            self.assertIn(str(root/'unchanged.py'),filtered)
            live=lambda path,name: published+b'\trefs/heads/main\n'
            git('reset','--hard',head.decode())
            restore={}
            exclusions,_=repository_exclusions(root,live,restore)
            self.assertIn(str(root/'source.py'),exclusions)
            self.assertEqual(restore['head'],head.decode())
            self.assertNotIn(str(root/'untracked-original.txt'),exclusions)
            git('tag','-a','unpublished-tag','-m','unique annotation')
            self.assertEqual(repository_exclusions(root,live)[0],[])
            def unavailable(path,name): raise subprocess.TimeoutExpired('git',25)
            self.assertEqual(repository_exclusions(root,unavailable)[0],[])

if __name__=='__main__': unittest.main()
