require 'rails_helper'

describe Gitlab::Gpg::Commit do
  describe '#signature' do
    let!(:project) { create :project, :repository, path: 'sample-project' }
    let!(:commit_sha) { '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33' }

    context 'unsigned commit' do
      let!(:commit) { create :commit, project: project, sha: commit_sha }

      it 'returns nil' do
        expect(described_class.new(commit).signature).to be_nil
      end
    end

    context 'known key' do
      context 'user matches the key uid' do
        context 'user matches the committer' do
          let!(:commit) { create :commit, project: project, sha: commit_sha, committer_email: GpgHelpers::User1.emails.first }

          let!(:user) { create(:user, email: GpgHelpers::User1.emails.first) }

          let!(:gpg_key) do
            create :gpg_key, key: GpgHelpers::User1.public_key, user: user
          end

          before do
            allow(Rugged::Commit).to receive(:extract_signature)
            .with(Rugged::Repository, commit_sha)
            .and_return(
              [
                GpgHelpers::User1.signed_commit_signature,
                GpgHelpers::User1.signed_commit_base_data
              ]
            )
          end

          it 'returns a valid signature' do
            expect(described_class.new(commit).signature).to have_attributes(
              commit_sha: commit_sha,
              project: project,
              gpg_key: gpg_key,
              gpg_key_primary_keyid: GpgHelpers::User1.primary_keyid,
              gpg_key_user_name: GpgHelpers::User1.names.first,
              gpg_key_user_email: GpgHelpers::User1.emails.first,
              valid_signature: true,
              verification_status: 'verified'
            )
          end

          it 'returns the cached signature on second call' do
            gpg_commit = described_class.new(commit)

            expect(gpg_commit).to receive(:using_keychain).and_call_original
            gpg_commit.signature

            # consecutive call
            expect(gpg_commit).not_to receive(:using_keychain).and_call_original
            gpg_commit.signature
          end
        end

        context 'user does not match the committer' do
          let!(:commit) { create :commit, project: project, sha: commit_sha, committer_email: GpgHelpers::User2.emails.first }

          let(:user) { create(:user, email: GpgHelpers::User1.emails.first) }

          let!(:gpg_key) do
            create :gpg_key, key: GpgHelpers::User1.public_key, user: user
          end

          before do
            allow(Rugged::Commit).to receive(:extract_signature)
            .with(Rugged::Repository, commit_sha)
            .and_return(
              [
                GpgHelpers::User1.signed_commit_signature,
                GpgHelpers::User1.signed_commit_base_data
              ]
            )
          end

          it 'returns an invalid signature' do
            expect(described_class.new(commit).signature).to have_attributes(
              commit_sha: commit_sha,
              project: project,
              gpg_key: gpg_key,
              gpg_key_primary_keyid: GpgHelpers::User1.primary_keyid,
              gpg_key_user_name: GpgHelpers::User1.names.first,
              gpg_key_user_email: GpgHelpers::User1.emails.first,
              valid_signature: false,
              verification_status: 'other_user'
            )
          end
        end
      end

      context 'user does not match the key uid' do
        let!(:commit) { create :commit, project: project, sha: commit_sha }

        let(:user) { create(:user, email: GpgHelpers::User2.emails.first) }

        let!(:gpg_key) do
          create :gpg_key, key: GpgHelpers::User1.public_key, user: user
        end

        before do
          allow(Rugged::Commit).to receive(:extract_signature)
          .with(Rugged::Repository, commit_sha)
          .and_return(
            [
              GpgHelpers::User1.signed_commit_signature,
              GpgHelpers::User1.signed_commit_base_data
            ]
          )
        end

        it 'returns an invalid signature' do
          expect(described_class.new(commit).signature).to have_attributes(
            commit_sha: commit_sha,
            project: project,
            gpg_key: gpg_key,
            gpg_key_primary_keyid: GpgHelpers::User1.primary_keyid,
            gpg_key_user_name: GpgHelpers::User1.names.first,
            gpg_key_user_email: GpgHelpers::User1.emails.first,
            valid_signature: false,
            verification_status: 'unverified_key'
          )
        end
      end
    end

    context 'unknown key' do
      let!(:commit) { create :commit, project: project, sha: commit_sha }

      before do
        allow(Rugged::Commit).to receive(:extract_signature)
          .with(Rugged::Repository, commit_sha)
          .and_return(
            [
              GpgHelpers::User1.signed_commit_signature,
              GpgHelpers::User1.signed_commit_base_data
            ]
          )
      end

      it 'returns an invalid signature' do
        expect(described_class.new(commit).signature).to have_attributes(
          commit_sha: commit_sha,
          project: project,
          gpg_key: nil,
          gpg_key_primary_keyid: GpgHelpers::User1.primary_keyid,
          gpg_key_user_name: nil,
          gpg_key_user_email: nil,
          valid_signature: false,
          verification_status: 'unknown_key'
        )
      end

      it 'returns the cached signature on second call' do
        gpg_commit = described_class.new(commit)

        expect(gpg_commit).to receive(:using_keychain).and_call_original
        gpg_commit.signature

        # consecutive call
        expect(gpg_commit).not_to receive(:using_keychain).and_call_original
        gpg_commit.signature
      end
    end
  end
end
