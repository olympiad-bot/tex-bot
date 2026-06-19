import os
from io import BytesIO

import discord
from discord import app_commands
from tex2image.client import TexRenderingClient


TOKEN = os.environ["TOKEN"]

TEST_GUILD = (
    discord.Object(id=guild_id)
    if (guild_id := os.environ.get("TEST_GUILD_ID")) is not None
    else None
)


class LatexBotClient(discord.Client):
    def __init__(self, *, intents: discord.Intents):
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        if TEST_GUILD:
            self.tree.copy_global_to(guild=TEST_GUILD)
            await self.tree.sync(guild=TEST_GUILD)
        await self.tree.sync()


intents = discord.Intents.default()
client = LatexBotClient(intents=intents)

tex2image_client = TexRenderingClient(
    os.environ.get("TEX2IMAGE_HOST", "localhost"),
    os.environ.get("TEX2IMAGE_PORT", 8000),
)


@client.tree.command()
@app_commands.user_install()
@app_commands.describe(
    latex_snippet="Latex snippet to render.",
    ephemeral="If true, then the message with image will only be visible to you.",
)
async def latex(
    interaction: discord.Interaction, latex_snippet: str, ephemeral: bool = False
) -> None:
    """Render `latex_snippet` to an image."""
    await interaction.response.send_message(
        file=discord.File(
            BytesIO(tex2image_client.request_latex_to_png(latex_snippet)),
            filename="latex.png",
        ),
        ephemeral=ephemeral,
    )


client.run(TOKEN)
