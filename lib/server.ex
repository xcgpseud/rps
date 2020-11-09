defmodule Rochambo.Server do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: {:global, :game})
  end

  def status() do
    GenServer.call({:global, :game}, :status)
  end

  def join(name) do
    GenServer.call({:global, :game}, {:join, name})
  end

  def get_players() do
    GenServer.call({:global, :game}, :get_players)
  end

  # -- Server Functions -- #

  @impl true
  def init(:ok) do
    players = %{}
    scores = %{}
    hands = %{}
    {:ok, {players, scores, hands}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {players, _, _} = state

    cond do
      length(Map.keys(players)) == 2 ->
        {:reply, :waiting_for_gambits, state}

      true ->
        {:reply, :need_players, state}
    end
  end

  # Can not seem to be able to join from 2 separate terminals. Perhaps I misunderstood this part but
  # I assumed the {:global, name} identifier would allow me to do this.
  def handle_call({:join, name}, _from, state) do
    {players, scores, hands} = state
    {pid, _} = _from

    cond do
      length(Map.keys(players)) == 2 ->
        {:reply, {:error, "Already full!"}, state}

      Map.has_key?(players, pid) ->
        {:reply, {:error, "Already joined!"}, state}

      true ->
        # Fresh data for the user, using their PID as the key
        new_players = Map.put(players, pid, name)
        new_scores = Map.put(scores, pid, 0)
        new_hands = Map.put(hands, pid, :empty)
        {:reply, :joined, {new_players, new_scores, new_hands}}
    end
  end

  def handle_call(:get_players, _from, state) do
    {players, _, _} = state
    {:reply, Map.values(players), state}
  end

  def handle_call({:play, hand}, _from, state) do
    {players, scores, hands} = state
    {pid, _} = _from

    new_hands = Map.replace!(hands, pid, hand)

    # This is the part I'm struggling with.

    # I want to:
    # - Make sure both players have played (unsure how to verify this)
    # - Run play(left, right) where left/right are both hands, player1/player2
    # - Update the scores map, incrementing the winning pid by 1
    # - Reset the hands map for each pid to :empty

    # So, without verifying that both have played I suppose:

    # Edit: on afterthought, if I clear the hands map every time, then I can just make sure its length is 2...
    # Too late now!

    [left, right] = Map.values(new_hands)
    winner = play(left, right)

    [left_pid, right_pid] = Map.keys(new_hands)

    winner_pid = case winner do
      :left -> left_pid
      :right -> right_pid
    end

    new_scores = Map.update!(scores, winner_pid, fn i -> i + 1 end)

    # Need to tell the playing user (_from) that they won/lost. I have both PIDs also, but not sure how to send this.

    # Reset data now and send it back

    empty_hands = new_hands
                  |> Map.replace!(left_pid, :empty)
                  |> Map.replace!(right_pid, :empty)

    {:noreply, {players, new_scores, empty_hands}}

    # But return with new_hands if both players haven't played so that when the last player goes they have the data
  end

  def handle_call(:scores, _from, state) do
    {_, scores, _} = state
    {:reply, scores, state}
  end

  def play(:rock, :scissors) do
    :left
  end

  def play(:scissors, :paper) do
    :left
  end


  def play(:paper, :rock) do
    :left
  end

  def play(left, right) when left == right do
    :draw
  end

  def play(_, _) do
    :right
  end
end
