describe Team do
  let(:assignment) { build(:assignment, id: 1, name: 'no assgt') }
  let(:participant) { build(:participant, user_id: 1) }
  let(:participant2) { build(:participant, user_id: 2) }
  let(:participant3) { build(:participant, user_id: 3) }
  let(:user) { build(:student, id: 1, name: 'no name', fullname: 'no one', participants: [participant]) }
  let(:user2) { build(:student, id: 2) }
  let(:user3) { build(:student, id: 3) }
  let(:team) { build(:assignment_team, id: 1, name: 'no team', users: [user]) }
  let(:team_user) { build(:team_user, id: 1, user: user) }
  let(:assignment_team) { build(:assignment_team) }
  before(:each) do
    allow(TeamsUser).to receive(:where).with(team_id: 1).and_return([team_user])
  end
  describe '#participant' do
    it 'gets the participants of current team, by default returns an empty array' do
      expect(team.participants).to eq([])
    end
  end

  describe '#responses' do
    it 'gets the response done by participants in current team, by default returns an empty array' do
      expect(team.responses).to eq([])
    end
  end

  describe '#delete' do
    it 'deletes the current team and related objects and return self' do
      allow(TeamsUser).to receive_message_chain(:where, :find_each).with(team_id: 1).with(no_args).and_yield(team_user)
      allow(team_user).to receive(:destroy).and_return(team_user)
      node = double('TeamNode')
      allow(TeamNode).to receive(:find_by).with(node_object_id: 1).and_return(node)
      allow(node).to receive(:destroy).and_return(node)
      expect(team.delete).to eq(team)
    end
  end

  describe '#node_type' do
    it 'always returns TeamNode' do
      expect(team.node_type).to eq('TeamNode')
    end
  end

  describe '#author_names' do
    it 'returns an array of author\'s name' do
      expect(team.author_names).to eq(['no one'])
    end
  end

  describe '#user?' do
    context 'when users in current team includes the parameterized user' do
      it 'returns true' do
        expect(team.user?(user)).to be true
      end
    end

    context 'when users in current team does not include the parameterized user' do
      it 'returns false' do
        expect(team.user?(double('User'))).to be false
      end
    end
  end

  describe '#full?' do
    context 'when the parent_id of current team is nil' do
      it 'returns false' do
        team.parent_id = nil
        expect(team.full?).to be false
      end
    end

    context 'when the parent_id of current team is not nil' do
      before(:each) do
        allow(Assignment).to receive(:find).with(1).and_return(assignment)
      end
      context 'when the current team size is bigger than or equal to max team members' do
        it 'returns true' do
          allow(Team).to receive(:size).and_return(6)
          expect(team.full?).to be true
        end
      end

      context 'when the current team size is smaller than max team members' do
        it 'returns false' do
          allow(Team).to receive(:size).and_return(1)
          expect(team.full?).to be false
        end
      end
    end
  end

  describe '#add_member' do
    context 'when parameterized user has already joined in current team' do
      it 'raise an error' do
        expect { team.add_member(user) }.to raise_error(RuntimeError, "The user #{user.name} is already a member of the team #{team.name}")
      end
    end

    context 'when parameterized user did not join in current team yet' do
      context 'when current team is not full' do
        it 'does not raise an error' do
          allow_any_instance_of(Team).to receive(:user?).with(user).and_return(false)
          allow_any_instance_of(Team).to receive(:full?).and_return(false)
          allow(TeamsUser).to receive(:create).with(user_id: 1, team_id: 1).and_return(team_user)
          allow(TeamNode).to receive(:find_by).with(node_object_id: 1).and_return(double('TeamNode', id: 1))
          allow_any_instance_of(Team).to receive(:add_participant).with(1, user).and_return(double('Participant'))
          expect(team.add_member(user)).to be true
        end
      end
    end
  end

  describe '.size' do
    it 'returns the size of current team' do
      expect(Team.size(1)).to eq(1)
    end
  end

  describe '#copy_members' do
    it 'copies members from current team to a new team' do
      allow(TeamsUser).to receive(:create).with(team_id: 2, user_id: 1).and_return(team_user)
      allow(Assignment).to receive(:find).with(1).and_return(assignment)
      expect(team.copy_members(double('Team', id: 2))).to eq([team_user])
    end
  end

  describe '.check_for_existing' do
    context 'when team exists' do
      it 'raises a TeamExistsError' do
        allow(AssignmentTeam).to receive(:where).with(parent_id: 1, name: 'no name').and_return([team])
        expect { Team.check_for_existing(assignment, 'no name', 'Assignment') }
          .to raise_error(TeamExistsError, 'The team name no name is already in use.')
      end
    end

    context 'when team exists' do
      it 'returns nil' do
        allow(AssignmentTeam).to receive(:where).with(parent_id: 1, name: 'no name').and_return([])
        expect(Team.check_for_existing(assignment, 'no name', 'Assignment')).to be nil
      end
    end
  end

  describe '.randomize_all_by_parent' do
    it 'forms teams and assigns team members automatically' do
      allow(Participant).to receive(:where).with(parent_id: 1, type: 'AssignmentParticipant', can_mentor: [false, nil])
                                           .and_return([participant, participant2, participant3])
      allow(User).to receive(:find).with(1).and_return(user)
      allow(User).to receive(:find).with(2).and_return(user2)
      allow(User).to receive(:find).with(3).and_return(user3)
      allow(Team).to receive(:where).with(parent_id: 1, type: 'AssignmentTeam').and_return([team])
      allow(Team).to receive(:size).with(any_args).and_return(1)
      allow_any_instance_of(Team).to receive(:add_member).with(any_args).and_return(true)
      expect(Team.randomize_all_by_parent(assignment, 'Assignment', 2)).to eq([1])
    end
  end

  describe '.generate_team_name' do
    it 'generates the unused team name' do
      expect(Team.generate_team_name('Assignment')).to eq('Assignment Team_1')
    end
  end

  describe '.import_team_members' do
    context 'when cannot find a user by name' do
      it 'raises an ImportError' do
        allow(User).to receive(:find_by).with(name: 'no name').and_return(nil)
        expect { team.import_team_members(teammembers: ['no name']) }.to raise_error(ImportError,
                                                                                     'The user \'no name\' was not found. <a href=\'/users/new\'>Create</a> this user?')
      end
    end

    context 'when can find certain user' do
      it 'adds the user to current team' do
        allow(User).to receive(:find_by).with(name: 'no name').and_return(user)
        allow(TeamsUser).to receive(:find_by).with(team_id: 1, user_id: 1).and_return(nil)
        allow_any_instance_of(Team).to receive(:add_member).with(user).and_return(true)
        expect(team.import_team_members(teammembers: ['no name'])).to eq(['no name'])
      end
    end
  end

  # E1991 : we check whether anonymized view
  # sets the team name to anonymized. the test
  # case should test both when anonymized view
  # is set and when anonymized view is not set
  describe '#anonymized_view' do
    it 'returns anonymized name of team when anonymized view is set' do
      allow(User).to receive(:anonymized_view?).and_return(true)
      expect(team.name).to eq 'Anonymized_Team_' + team.id.to_s
      expect(team.name).not_to eq 'no team'
    end

    it 'returns real name of team when anonymized view is not set' do
      allow(User).to receive(:anonymized_view?).and_return(false)
      expect(team.name).not_to eq 'Team_' + team.id.to_s
      expect(team.name).to eq 'no team'
    end
  end

  describe '.import_helper' do
    let(:options) do
      { handle_dups: 'ignore' }
    end

    context 'when no handle duplicates option provided' do
      it 'raises an ArgumentError' do
        expect { Team.import_helper({}, 1, { has_column_names: 'false' }, AssignmentTeam.new) }
          .to raise_error(ArgumentError, 'Include duplicate handling option.')
      end
    end

    context 'when teamname provided' do
      let(:row) do
        { teamname: 'Ruby', teammembers: 'none' }
      end
      it 'uses provided teamname' do
        allow(Team).to receive(:where).with(any_args).and_return(team)
        allow(team).to receive(:first).and_return(team)
        allow(team).to receive(:nil?).and_return(false)
        allow(Team).to receive(:handle_duplicate).and_return('Ruby')
        allow(team).to receive(:import_team_members).with(any_args).and_return(nil)
        allow(Object).to receive_message_chain(:const_get, :create_team_and_node).and_return(team)
        expect(team).to receive(:save) # Expect the object creation in the database

        Team.import_helper(row, 1, options, AssignmentTeam.prototype)
      end
    end

    context 'when teamname is not provided' do
      let(:row) do
        { teammembers: 'none' }
      end
      it 'generates a teamname' do
        allow(Assignment).to receive(:find).with(any_args).and_return(assignment)
        allow(Team).to receive(:generate_team_name).with(assignment.name).and_return('Not a team')
        allow(AssignmentTeam).to receive(:create_team_and_node).with(any_args).and_return(team)
        allow(Object).to receive_message_chain(:const_get, :create_team_and_node).and_return(team)
        allow(AssignmentTeam).to receive(:is_a?).with(AssignmentTeam).and_return(true)
        allow(team).to receive(:import_team_members).with(any_args).and_return(nil)
        expect(Team).to receive(:generate_team_name).with(assignment.name) # Expect a team name will be generated if not provided
        expect(team).to receive(:save) # Expect the object creation in the database

        Team.import_helper(row, 1, options, assignment_team)
      end
    end
  end

  describe '.handle_duplicate' do
    context 'when parameterized team is nil' do
      it 'returns team name' do
        expect(Team.handle_duplicate(nil, 'no name', 1, 'replace', CourseTeam.new)).to eq('no name')
      end
    end

    context 'when parameterized team is not nil' do
      context 'when handle_dups option is ignore' do
        it 'does not create the new team and returns nil' do
          expect(Team.handle_duplicate(team, 'no name', 1, 'ignore', CourseTeam.new)).to be nil
        end
      end

      context 'when handle_dups option is rename' do
        it 'returns new team name' do
          allow(Course).to receive(:find).with(1).and_return(double('Course', name: 'no course'))
          allow(Assignment).to receive(:find).with(1).and_return(double('Assignment', name: 'no assignment'))
          allow(Team).to receive(:generate_team_name).with('no course').and_return('new team name')
          allow(Team).to receive(:generate_team_name).with('no assignment').and_return('new team name')
          expect(Team.handle_duplicate(team, 'no name', 1, 'rename', CourseTeam.new)).to eq('new team name')
          expect(Team.handle_duplicate(team, 'no name', 1, 'rename', AssignmentTeam.new)).to eq('new team name')
        end
      end

      context 'when handle_dups option is replace' do
        it 'deletes the old team' do
          allow(team).to receive(:delete)
          expect(Team.handle_duplicate(team, 'no name', 1, 'replace', CourseTeam.new)).to eq('no name')
        end
      end

      context 'when handle_dups option is insert' do
        it 'does nothing and returns nil' do
          expect(Team.handle_duplicate(team, 'no name', 1, 'insert', CourseTeam.new)).to be nil
        end
      end

      # By the time this test is added (by E1949), the renaming existing team function does not exist yet,
      # so it should fail unless the function is implemented and the existing team is renamed and saved.
      context 'when handle_dups option is rename_existing' do
        it 'renames the existing team and returns nil' do
          allow(Course).to receive(:find).with(1).and_return(double('Course', name: 'no course'))
          allow(Assignment).to receive(:find).with(1).and_return(double('Assignment', name: 'no assignment'))
          allow(Team).to receive(:generate_team_name).with('no course').and_return('new team name')
          allow(Team).to receive(:generate_team_name).with('no assignment').and_return('new team name')
          allow(team).to receive(:name=).with('new team name')
          allow(team).to receive(:save)
          expect(Team.handle_duplicate(team, 'no name', 1, 'replace_existing', CourseTeam.new)).to be nil
          expect(Team.handle_duplicate(team, 'no name', 1, 'replace_existing', AssignmentTeam.new)).to be nil
        end
      end
    end
  end

  describe '.export' do
    it 'exports teams to csv' do
      allow(AssignmentTeam).to receive(:where).with(parent_id: 1).and_return([team])
      allow(TeamsUser).to receive(:where).with(team_id: 1).and_return([team_user])
      expect(Team.export([], 1, { team_name: 'false' }, AssignmentTeam.new)).to eq([['no team', 'no name']])
    end
  end
end
