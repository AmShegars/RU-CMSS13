import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

type Data = {
  allowed: BooleanLike;
  items: { ref: string; name: string }[];
};

export const NoticeBoard = (props, context) => {
  const { act, data } = useBackend<Data>(context);
  const { allowed, items = [] } = data;

  return (
    <Window width={425} height={176}>
      <Window.Content backgroundColor="#704D25">
        {!items.length ? (
          <Section>
            <Box color="white" align="center">
              The notice board is empty!
            </Box>
          </Section>
        ) : (
          items.map((item) => (
            <Stack
              key={item.ref}
              color="black"
              backgroundColor="white"
              style={{ padding: '2px 2px 0 2px' }}>
              <Stack.Item align="center" grow>
                <Box align="center">{item.name}</Box>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="eye"
                  onClick={() => act('examine', { ref: item.ref })}
                />
                <Button
                  icon="pen"
                  onClick={() => act('write', { ref: item.ref })}
                />
                <Button
                  icon="eject"
                  disabled={!allowed}
                  onClick={() => act('remove', { ref: item.ref })}
                />
              </Stack.Item>
            </Stack>
          ))
        )}
      </Window.Content>
    </Window>
  );
};
