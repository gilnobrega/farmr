module.exports = async(client, oldMember, newMember) => {
	// It's good practice to ignore other bots. This also makes your bot ignore itself
	// and not get into a spam loop (we call that "botception").
	if (newMember.bot)
		return;
};
