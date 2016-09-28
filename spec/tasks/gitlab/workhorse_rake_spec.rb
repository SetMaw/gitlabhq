require 'spec_helper'
require 'rake'

describe 'gitlab:workhorse namespace rake task' do
  before :all do
    Rake.application.rake_require 'tasks/gitlab/task_helpers'
    Rake.application.rake_require 'tasks/gitlab/workhorse'

    # empty task as env is already loaded
    Rake::Task.define_task :environment
  end

  def run_rake_task(task_name, *args)
    Rake::Task[task_name].reenable
    Rake.application.invoke_task("#{task_name}[#{args.join(',')}]")
  end

  describe 'install' do
    let(:repo) { 'https://gitlab.com/gitlab-org/gitlab-workhorse.git' }
    let(:clone_path) { Rails.root.join('tmp/tests/gitlab-workhorse').to_s }
    let(:tag) { "v#{File.read(Rails.root.join(Gitlab::Workhorse::VERSION_FILE)).chomp}" }
    before do
      # avoid writing task output to spec progress
      allow($stdout).to receive :write
      allow(ENV).to receive(:[])
    end

    context 'no dir given' do
      it 'aborts and display a help message' do
        expect { run_rake_task('gitlab:workhorse:install') }.to raise_error /Please specify the directory where you want to install gitlab-workhorse/
      end
    end

    context 'when an underlying Git command fail' do
      it 'aborts and display a help message' do
        expect_any_instance_of(Object).
          to receive(:checkout_or_clone_tag).and_raise 'Git error'

        expect { run_rake_task('gitlab:workhorse:install', clone_path) }.to raise_error 'Git error'
      end
    end

    describe 'checkout or clone' do
      before do
        expect(Dir).to receive(:chdir).with(clone_path)
      end

      it 'calls checkout_or_clone_tag with the right arguments' do
        expect_any_instance_of(Object).
          to receive(:checkout_or_clone_tag).with(tag: tag, repo: repo, target_dir: clone_path)

        run_rake_task('gitlab:workhorse:install', clone_path)
      end

      context 'given a specific repo' do
        before do
          expect(ENV).to receive(:[]).with('GITLAB_WORKHORSE_REPO').and_return('https://gitlab.com/user1/gitlab-workhorse.git')
        end

        it 'calls checkout_or_clone_tag with the given repo' do
          expect_any_instance_of(Object).
            to receive(:checkout_or_clone_tag).with(tag: tag, repo: 'https://gitlab.com/user1/gitlab-workhorse.git', target_dir: clone_path)

          run_rake_task('gitlab:workhorse:install', clone_path)
        end
      end

      context 'given a specific version' do
        before do
          allow(ENV).to receive(:[]).with('GITLAB_WORKHORSE_VERSION').and_return('42.42.0')
        end

        it 'calls checkout_or_clone_tag with the given repo' do
          expect_any_instance_of(Object).
            to receive(:checkout_or_clone_tag).with(tag: 'v42.42.0', repo: repo, target_dir: clone_path)

          run_rake_task('gitlab:workhorse:install', clone_path)
        end
      end
    end

    describe 'gmake/make' do
      before do
        FileUtils.mkdir_p(clone_path)
        expect(Dir).to receive(:chdir).with(clone_path).and_call_original
      end

      context 'gmake is available' do
        before do
          expect_any_instance_of(Object).to receive(:checkout_or_clone_tag)
          allow_any_instance_of(Object).to receive(:run_command).with(['gmake']).and_return(true)
        end

        it 'calls gmake in the gitlab-workhorse directory' do
          expect(Gitlab::Popen).to receive(:popen).with(%w[which gmake]).and_return(['/usr/bin/gmake', 0])
          expect_any_instance_of(Object).to receive(:run_command).with(['gmake']).and_return(true)

          run_rake_task('gitlab:workhorse:install', clone_path)
        end
      end

      context 'gmake is not available' do
        before do
          expect_any_instance_of(Object).to receive(:checkout_or_clone_tag)
          allow_any_instance_of(Object).to receive(:run_command).with(['make']).and_return(true)
        end

        it 'calls make in the gitlab-workhorse directory' do
          expect(Gitlab::Popen).to receive(:popen).with(%w[which gmake]).and_return(['', 42])
          expect_any_instance_of(Object).to receive(:run_command).with(['make']).and_return(true)

          run_rake_task('gitlab:workhorse:install', clone_path)
        end
      end
    end
  end
end
